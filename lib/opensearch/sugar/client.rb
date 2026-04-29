# frozen_string_literal: true

require "delegate"
require "opensearch-ruby"
require_relative "models"
require "httpx/adapters/faraday"

module OpenSearch::Sugar
  class Client < SimpleDelegator
    # Creates a new raw OpenSearch client instance
    #
    # @param args [Array] Arguments to pass to the OpenSearch::Client constructor
    # @param kwargs [Hash] Keyword arguments to pass to the OpenSearch::Client constructor
    # @return [OpenSearch::Client] A new raw client instance
    def self.raw_client(*args, **kwargs)
      ::OpenSearch::Client.new(*args, **kwargs)
    end

    attr_reader :raw_client, :models
    # Creates a new OpenSearch::Sugar::Client instance
    #
    # @param host [String] The OpenSearch host to connect to
    # @param kwargs [Hash] Additional arguments to pass to the OpenSearch::Client constructor
    # @return [OpenSearch::Sugar::Client] A new client instance
    # @see [OpenSearch::Client]
    def initialize(host: ENV["OPENSEARCH_URL"] || ENV["OPENSEARCH_HOST"] || "https://localhost:9000", **kwargs)
      kwargs[:host] = host
      args = default_args.merge(kwargs)
      @raw_client = self.class.raw_client(**args)
      __setobj__(@raw_client)
      @models = Models.new(self)
    end

    # Returns the default arguments for the OpenSearch client
    #
    # @return [Hash] The default connection arguments
    def default_args
      {
        user: ENV["OPENSEARCH_USER"] || "admin",
        password: ENV["OPENSEARCH_PASSWORD"] || ENV["OPENSEARCH_INITIAL_ADMIN_PASSWORD"],
        host: ENV["OPENSEARCH_URL"] || "https://localhost:9000",
        retry_on_failure: 5,
        request_timeout: 5,
        log: true,
        trace: false,
        transport_options: {ssl: {verify: false}}
      }
    end

    # Set the log level. You can use a specific logger, or default to the root logger
    # See https://docs.opensearch.org/latest/install-and-configure/configuring-opensearch/logs/
    def set_log_level(logger: "logger._root", level: "warn")
      http.put("_cluster/settings", body: {persistent: {logger.to_s => level.to_s}})
    end

    # Checks if an index exists in OpenSearch
    #
    # @param name [String] The name of the index to check
    # @return [Boolean] True if the index exists, false otherwise
    def has_index?(name)
      indices.exists?(index: name)
    end

    def index_names
      cluster.state["metadata"]["indices"].keys
    end

    # Retrieves an index by name
    #
    # @param index_name [String] The name of the index to retrieve
    # @return [OpenSearch::Sugar::Index] The index instance
    def [](index_name)
      Index.open(client: self, name: index_name)
    end

    def open_or_create(index_name)
      Index.open(client: self, name: index_name)
    rescue ArgumentError
      Index.create(client: self, name: index_name)
    end

    # Uploads settings to an OpenSearch index
    #
    # This method will:
    # 1. Close the index
    # 2. Apply the new settings
    # 3. Reopen the index
    #
    # @param settings [Hash] The settings to upload
    # @param index_name [String] The name of the index to update
    # @return [Hash] The response from OpenSearch on success
    # @raise [OpenSearch::Sugar::Error] If the settings update fails
    # @example
    #   settings = {
    #     settings: {
    #       analysis: {
    #         analyzer: {
    #           my_analyzer: {
    #             type: "custom",
    #             tokenizer: "standard"
    #           }
    #         }
    #       }
    #     }
    #   }
    #   client.update_settings(settings, "my_index")
    def update_settings(settings, index_name)
      # Extract the actual OpenSearch settings from our enhanced settings object
      opensearch_settings = if settings.keys.map(&:to_s) == ["settings"]
        settings.values.first
      else
        settings
      end
      indices.close(index: index_name)
      indices.put_settings(index: index_name, body: opensearch_settings)
      indices.open(index: index_name)
    rescue => e
      reopen_index(index_name)
      raise OpenSearch::Sugar::Error, "Failed to update settings for #{index_name}: #{e.message}"
    end

    # Uploads mappings to an OpenSearch index
    #
    # This method will:
    # 1. Close the index
    # 2. Apply the new mappings
    # 3. Reopen the index
    #
    # @param mappings [Hash] The mappings to upload
    # @param index_name [String] The name of the index to update
    # @return [Hash] The response from OpenSearch on success
    # @raise [OpenSearch::Sugar::Error] If the mappings update fails
    # @example
    #   mappings = {
    #     mappings: {
    #       properties: {
    #         title: { type: "text" },
    #         description: { type: "text" },
    #         created_at: { type: "date" }
    #       }
    #     }
    #   }
    #   client.update_mappings(mappings, "my_index")
    def update_mappings(mappings, index_name)
      # Extract the actual OpenSearch settings from our enhanced settings object
      opensearch_mappings = if mappings.keys.map(&:to_s) == ["mappings"]
        mappings.values.first
      else
        mappings
      end
      indices.close(index: index_name)
      indices.put_mapping(index: index_name, body: opensearch_mappings)
      indices.open(index: index_name)
    rescue => e
      reopen_index(index_name)
      raise OpenSearch::Sugar::Error, "Failed to update mappings for #{index_name}: #{e.message}"
    end

    private

    # Helper method to safely reopen an index if it's closed
    #
    # @param index_name [String] The name of the index to reopen
    # @return [void]
    def reopen_index(index_name)
      indices.open(index: index_name)
    rescue => open_error
      # Just log the error without raising
      puts "Warning: Failed to reopen index #{index_name}: #{open_error.message}"
    end
  end
end
