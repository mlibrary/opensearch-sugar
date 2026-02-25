# frozen_string_literal: true

require "delegate"
require "opensearch-ruby"
require_relative "models"
require "httpx/adapters/faraday"
require "logger"

module OpenSearch::Sugar
  # OpenSearch client wrapper providing syntactic sugar and convenience methods
  #
  # This class wraps the OpenSearch::Client and provides additional functionality
  # including index management, settings updates, and model operations.
  #
  # @example Create a client
  #   client = OpenSearch::Sugar::Client.new
  #   client = OpenSearch::Sugar::Client.new(host: "https://localhost:9200")
  class Client < SimpleDelegator
    # Default connection timeout in seconds
    DEFAULT_TIMEOUT = 5

    # Default number of retry attempts
    DEFAULT_RETRIES = 5

    # Valid log levels for OpenSearch cluster logging
    VALID_LOG_LEVELS = %w[trace debug info warn error].freeze

    # Creates a new raw OpenSearch client instance
    #
    # @param args [Array] Arguments to pass to the OpenSearch::Client constructor
    # @param kwargs [Hash] Keyword arguments to pass to the OpenSearch::Client constructor
    # @return [OpenSearch::Client] A new raw client instance
    def self.raw_client(*args, **kwargs) = ::OpenSearch::Client.new(*args, **kwargs)

    attr_reader :raw_client, :models

    # Creates a new OpenSearch::Sugar::Client instance
    #
    # @param host [String] The OpenSearch host to connect to
    # @param user [String] Username for authentication (default: from ENV or "admin")
    # @param password [String] Password for authentication (default: from ENV)
    # @param timeout [Integer] Request timeout in seconds (default: 5)
    # @param retries [Integer] Number of retry attempts (default: 5)
    # @param logger [Logger, nil] Logger instance (default: creates new Logger)
    # @param kwargs [Hash] Additional arguments to pass to the OpenSearch::Client constructor
    # @return [OpenSearch::Sugar::Client] A new client instance
    # @raise [ArgumentError] If required credentials are missing
    # @see OpenSearch::Client
    # @example Create with custom settings
    #   client = OpenSearch::Sugar::Client.new(
    #     host: "https://localhost:9200",
    #     timeout: 10,
    #     retries: 3
    #   )
    def initialize(
      host: ENV["OPENSEARCH_URL"] || ENV["OPENSEARCH_HOST"] || "https://localhost:9200",
      user: nil,
      password: nil,
      timeout: DEFAULT_TIMEOUT,
      retries: DEFAULT_RETRIES,
      logger: nil,
      **kwargs
    )
      @logger = logger || Logger.new($stdout, level: Logger::INFO)

      connection_args = build_connection_args(
        host:,
        user:,
        password:,
        timeout:,
        retries:,
        **kwargs
      )

      @raw_client = self.class.raw_client(**connection_args)
      __setobj__(@raw_client)
      @models = Models.new(self)

      log_info("OpenSearch client initialized for host: #{sanitize_host_for_logging(host)}")
    rescue => e
      log_error("Failed to initialize OpenSearch client: #{e.message}")
      raise
    end

    # Returns the default arguments for the OpenSearch client
    #
    # @return [Hash] The default connection arguments
    # @api private
    def default_args
      {
        user: ENV["OPENSEARCH_USER"] || "admin",
        password: ENV["OPENSEARCH_PASSWORD"] || ENV["OPENSEARCH_INITIAL_ADMIN_PASSWORD"],
        host: ENV["OPENSEARCH_URL"] || "https://localhost:9200",
        retry_on_failure: DEFAULT_RETRIES,
        request_timeout: DEFAULT_TIMEOUT,
        log: false, # Use our logger instead
        trace: false,
        transport_options: {ssl: {verify: false}}
      }
    end

    # Sets the log level for OpenSearch cluster logging
    #
    # This method updates the cluster settings to change the logging level for a specific logger.
    # You can use a specific logger, or default to the root logger.
    #
    # @param logger_name [String] The logger name to configure (default: "logger._root")
    # @param level [String] The log level to set (default: "warn"). Valid values: "trace", "debug", "info", "warn", "error"
    # @return [Hash] The response from the OpenSearch cluster settings update
    # @raise [ArgumentError] If an invalid log level is provided
    # @raise [OpenSearchError] If the cluster settings update fails
    # @see https://docs.opensearch.org/latest/install-and-configure/configuring-opensearch/logs/
    # @see https://docs.opensearch.org/latest/api-reference/cluster-api/cluster-settings/
    # @example Set root logger to debug level
    #   client.set_log_level(level: "debug")
    # @example Set a specific logger to trace level
    #   client.set_log_level(logger_name: "logger.index.search.slowlog", level: "trace")
    def set_log_level(logger_name: "logger._root", level: "warn")
      validate_log_level!(level)

      log_info("Setting cluster log level: #{logger_name} => #{level}")

      response = http.put("_cluster/settings", body: {persistent: {logger_name.to_s => level.to_s}})

      log_debug("Cluster log level updated successfully")
      response
    rescue => e
      log_error("Failed to set cluster log level: #{e.message}")
      raise OpenSearchError, "Failed to update cluster log level: #{e.message}"
    end

    # Checks if an index exists in OpenSearch
    #
    # @param name [String] The name of the index to check
    # @return [Boolean] True if the index exists, false otherwise
    # @raise [OpenSearchError] If the existence check fails
    # @example
    #   client.index_exists?("my-index") # => true
    def index_exists?(name)
      indices.exists?(index: name)
    rescue => e
      log_error("Failed to check if index '#{name}' exists: #{e.message}")
      raise OpenSearchError, "Failed to check index existence: #{e.message}"
    end

    alias_method :has_index?, :index_exists?

    # Retrieves a list of all index names in the OpenSearch cluster
    #
    # @return [Array<String>] An array of index names in the cluster
    # @raise [OpenSearchError] If fetching index names fails
    # @see https://docs.opensearch.org/latest/api-reference/cluster-api/cluster-state/
    # @example Get all index names
    #   client.index_names
    #   # => ["my-index", "another-index", "test-index"]
    def index_names
      state = cluster.state
      state.dig("metadata", "indices")&.keys || []
    rescue => e
      log_error("Failed to fetch index names: #{e.message}")
      raise OpenSearchError, "Failed to fetch index names: #{e.message}"
    end

    # Retrieves an index by name
    #
    # @param index_name [String] The name of the index to retrieve
    # @return [OpenSearch::Sugar::Index] The index instance
    # @raise [ArgumentError] If the index does not exist
    # @example
    #   index = client["my-index"]
    def [](index_name)
      Index.open(client: self, name: index_name)
    end

    # Creates a new index
    #
    # This is a convenience method that delegates to Index.create.
    #
    # @param index_name [String] The name of the index to create
    # @param knn [Boolean] Whether to enable k-NN (default: true)
    # @param settings [Hash, nil] Additional index settings (optional)
    # @return [OpenSearch::Sugar::Index] The newly created index instance
    # @raise [ArgumentError] If the index already exists
    # @raise [OpenSearchError] If index creation fails
    # @see OpenSearch::Sugar::Index.create
    # @example Create a new index
    #   index = client.create_index("products", knn: true)
    # @example Create with custom settings
    #   index = client.create_index("products", settings: { number_of_shards: 3 })
    def create_index(index_name, knn: true, settings: nil)
      Index.create(client: self, name: index_name, knn:, settings:)
    end

    # Opens an existing index or creates it if it doesn't exist
    #
    # This method first attempts to open an existing index. If the index doesn't exist,
    # it creates a new index with the given name.
    #
    # @param index_name [String] The name of the index to open or create
    # @param knn [Boolean] Whether to enable k-NN if creating (default: true)
    # @param settings [Hash, nil] Additional index settings if creating (optional)
    # @return [OpenSearch::Sugar::Index] The opened or newly created index instance
    # @raise [OpenSearchError] If an error occurs other than the index not existing
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/create-index/
    # @example Open existing index or create if it doesn't exist
    #   index = client.open_or_create("my-index")
    # @example Open or create with custom settings
    #   index = client.open_or_create("my-index", knn: false, settings: { number_of_shards: 2 })
    def open_or_create(index_name, knn: true, settings: nil)
      log_debug("Attempting to open or create index: #{index_name}")
      Index.open_or_create(client: self, name: index_name, knn:, settings:)
    rescue => e
      log_error("Failed to open or create index '#{index_name}': #{e.message}")
      raise OpenSearchError, "Failed to open or create index: #{e.message}"
    end

    # Returns the logger instance
    #
    # @return [Logger] The logger instance
    # @api private
    attr_reader :logger

    private

    # Builds connection arguments for the OpenSearch client
    #
    # @param host [String] The OpenSearch host
    # @param user [String, nil] Username for authentication
    # @param password [String, nil] Password for authentication
    # @param timeout [Integer] Request timeout
    # @param retries [Integer] Number of retries
    # @param kwargs [Hash] Additional arguments
    # @return [Hash] Connection arguments
    # @api private
    def build_connection_args(host:, user:, password:, timeout:, retries:, **kwargs)
      args = default_args.merge(kwargs)
      args[:host] = host
      args[:user] = user if user
      args[:password] = password if password
      args[:request_timeout] = timeout
      args[:retry_on_failure] = retries
      args
    end

    # Validates that a log level is valid
    #
    # @param level [String] The log level to validate
    # @raise [ArgumentError] If the log level is invalid
    # @api private
    def validate_log_level!(level)
      return if VALID_LOG_LEVELS.include?(level.to_s.downcase)

      raise ArgumentError, "Invalid log level '#{level}'. Valid levels: #{VALID_LOG_LEVELS.join(", ")}"
    end

    # Sanitizes host URL for logging (removes credentials)
    #
    # @param host [String] The host URL
    # @return [String] Sanitized host URL
    # @api private
    def sanitize_host_for_logging(host)
      host.to_s.gsub(%r{://[^:]+:[^@]+@}, "://***:***@")
    end

    # Logs an info message
    #
    # @param message [String] The message to log
    # @api private
    def log_info(message) = logger.info("OpenSearch::Sugar::Client - #{message}")

    # Logs a debug message
    #
    # @param message [String] The message to log
    # @api private
    def log_debug(message) = logger.debug("OpenSearch::Sugar::Client - #{message}")

    # Logs a warning message
    #
    # @param message [String] The message to log
    # @api private
    def log_warn(message) = logger.warn("OpenSearch::Sugar::Client - #{message}")

    # Logs an error message
    #
    # @param message [String] The message to log
    # @api private
    def log_error(message) = logger.error("OpenSearch::Sugar::Client - #{message}")
  end
end
