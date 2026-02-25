# frozen_string_literal: true

require_relative "client"

module OpenSearch::Sugar
  # OpenSearch index wrapper providing convenience methods for index operations
  #
  # This class wraps OpenSearch index operations and provides a Ruby-friendly
  # interface for managing indices, documents, and search operations.
  #
  # @example Open an existing index
  #   index = OpenSearch::Sugar::Index.open(client: client, name: "my-index")
  #
  # @example Create a new index
  #   index = OpenSearch::Sugar::Index.create(client: client, name: "my-index")
  class Index
    # @return [OpenSearch::Sugar::Client] The client instance
    attr_reader :client

    # @return [String] The index name
    attr_reader :name

    # Opens an existing OpenSearch index
    #
    # This method verifies that the index exists before opening it.
    #
    # @param client [OpenSearch::Sugar::Client] The client instance to use for accessing the index
    # @param name [String] The name of the index to open
    # @return [OpenSearch::Sugar::Index] A new Index instance for the existing index
    # @raise [ArgumentError] If the index does not exist
    # @raise [ArgumentError] If client or name is nil
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/exists/
    # @example Open an existing index
    #   index = OpenSearch::Sugar::Index.open(client: client, name: "my-index")
    def self.open(client:, name:)
      raise ArgumentError, "Client cannot be nil" if client.nil?
      raise ArgumentError, "Index name cannot be nil" if name.nil?
      raise ArgumentError, "Index name cannot be empty" if name.to_s.strip.empty?
      raise ArgumentError, "Index '#{name}' not found" unless client.indices.exists?(index: name)

      new(client:, name:)
    end

    # Creates a new OpenSearch index
    #
    # This method creates a new index with the specified name and optional settings.
    # By default, k-NN (k-nearest neighbors) is enabled for vector search capabilities.
    #
    # @param client [OpenSearch::Sugar::Client] The client instance to use for creating the index
    # @param name [String] The name of the index to create
    # @param knn [Boolean] Whether to enable k-NN (k-nearest neighbors) support (default: true)
    # @param settings [Hash, nil] Additional index settings (optional)
    # @return [OpenSearch::Sugar::Index] A new Index instance for the created index
    # @raise [ArgumentError] If the index already exists
    # @raise [ArgumentError] If client or name is nil
    # @raise [OpenSearchError] If index creation fails
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/create-index/
    # @see https://docs.opensearch.org/latest/search-plugins/knn/index/
    # @example Create a new index with k-NN enabled
    #   index = OpenSearch::Sugar::Index.create(client: client, name: "my-index")
    # @example Create a new index without k-NN
    #   index = OpenSearch::Sugar::Index.create(client: client, name: "my-index", knn: false)
    # @example Create with custom settings
    #   index = OpenSearch::Sugar::Index.create(
    #     client: client,
    #     name: "my-index",
    #     settings: { number_of_shards: 3, number_of_replicas: 2 }
    #   )
    def self.create(client:, name:, knn: true, settings: nil)
      raise ArgumentError, "Client cannot be nil" if client.nil?
      raise ArgumentError, "Index name cannot be nil" if name.nil?
      raise ArgumentError, "Index name cannot be empty" if name.to_s.strip.empty?
      raise ArgumentError, "Index '#{name}' already exists" if client.indices.exists?(index: name)

      index_body = build_index_body(knn:, settings:)
      client.indices.create(index: name, body: index_body)

      new(client:, name:)
    rescue => e
      raise OpenSearchError, "Failed to create index '#{name}': #{e.message}"
    end

    # Opens an existing index or creates it if it doesn't exist
    #
    # This method first attempts to open an existing index. If the index doesn't exist,
    # it creates a new index with the given name and settings.
    #
    # @param client [OpenSearch::Sugar::Client] The client instance to use
    # @param name [String] The name of the index to open or create
    # @param knn [Boolean] Whether to enable k-NN if creating (default: true)
    # @param settings [Hash, nil] Additional index settings if creating (optional)
    # @return [OpenSearch::Sugar::Index] The opened or newly created index instance
    # @raise [OpenSearchError] If an error occurs other than the index not existing
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/create-index/
    # @example Open existing or create new index
    #   index = OpenSearch::Sugar::Index.open_or_create(client: client, name: "my-index")
    def self.open_or_create(client:, name:, knn: true, settings: nil)
      open(client:, name:)
    rescue ArgumentError => e
      if e.message.include?("not found")
        create(client:, name:, knn:, settings:)
      else
        raise
      end
    end

    # Checks if an index exists in OpenSearch
    #
    # @param client [OpenSearch::Sugar::Client] The client instance to use
    # @param name [String] The name of the index to check
    # @return [Boolean] True if the index exists, false otherwise
    # @raise [OpenSearchError] If the existence check fails
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/exists/
    # @example Check if index exists
    #   if OpenSearch::Sugar::Index.exists?(client: client, name: "my-index")
    #     puts "Index exists"
    #   end
    def self.exists?(client:, name:)
      raise ArgumentError, "Client cannot be nil" if client.nil?
      raise ArgumentError, "Index name cannot be nil" if name.nil?
      raise ArgumentError, "Index name cannot be empty" if name.to_s.strip.empty?

      client.indices.exists?(index: name)
    rescue => e
      raise OpenSearchError, "Failed to check if index exists: #{e.message}"
    end

    # Updates the settings for this index
    #
    # This method will:
    # 1. Close the index
    # 2. Apply the new settings
    # 3. Reopen the index
    #
    # @param settings [Hash] The settings to update
    # @return [Hash] A result hash with status, message, and metadata
    # @raise [ArgumentError] If settings is invalid
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/update-settings/
    # @example Update analyzer settings
    #   settings = {
    #     settings: {
    #       analysis: {
    #         analyzer: {
    #           my_analyzer: { type: "standard" }
    #         }
    #       }
    #     }
    #   }
    #   index.update_settings(settings)
    def update_settings(settings)
      raise ArgumentError, "Settings must be a Hash" unless settings.is_a?(Hash)
      raise ArgumentError, "Settings cannot be empty" if settings.empty?

      log_info("Updating settings for index: #{name}")

      # Extract the actual OpenSearch settings from our enhanced settings object
      opensearch_settings = extract_settings(settings, "settings")

      client.indices.close(index: name)
      log_debug("Index '#{name}' closed for settings update")

      client.indices.put_settings(index: name, body: opensearch_settings)
      log_debug("Settings applied to index '#{name}'")

      client.indices.open(index: name)
      log_debug("Index '#{name}' reopened")

      {
        status: :success,
        message: "Updated settings for index #{name}",
        metadata: settings[:metadata]
      }
    rescue ArgumentError
      raise
    rescue => e
      log_error("Failed to update settings: #{e.message}")

      # Try to reopen the index if it's closed
      reopen_index

      {
        status: :error,
        message: "Failed to update settings: #{e.message}",
        error: e.class.name,
        backtrace: e.backtrace.first(5)
      }
    end

    # Retrieves the current settings for this index
    #
    # @return [Hash] The index settings including analysis, number of shards, replicas, etc.
    # @raise [OpenSearchError] If fetching settings fails
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/get-settings/
    # @example Get index settings
    #   settings = index.settings
    #   puts settings[index.name]["settings"]["index"]["number_of_shards"]
    def settings
      client.indices.get_settings(index: name)
    rescue => e
      log_error("Failed to fetch settings: #{e.message}")
      raise OpenSearchError, "Failed to fetch index settings: #{e.message}"
    end

    # Updates the mappings for this index
    #
    # Note: In modern OpenSearch versions, most mapping updates don't require closing the index.
    #
    # @param mappings [Hash] The mappings to update
    # @return [Hash] A result hash with status, message, and metadata
    # @raise [ArgumentError] If mappings is invalid
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/put-mapping/
    # @example Update field mappings
    #   mappings = {
    #     mappings: {
    #       properties: {
    #         title: { type: "text" },
    #         timestamp: { type: "date" }
    #       }
    #     }
    #   }
    #   index.update_mappings(mappings)
    def update_mappings(mappings)
      raise ArgumentError, "Mappings must be a Hash" unless mappings.is_a?(Hash)
      raise ArgumentError, "Mappings cannot be empty" if mappings.empty?

      log_info("Updating mappings for index: #{name}")

      # Extract the actual OpenSearch mappings from our enhanced mappings object
      opensearch_mappings = extract_settings(mappings, "mappings")

      # Modern OpenSearch versions don't require closing for mapping updates
      client.indices.put_mapping(index: name, body: opensearch_mappings)
      log_debug("Mappings applied to index '#{name}'")

      {
        status: :success,
        message: "Updated mappings for index #{name}",
        metadata: mappings[:metadata]
      }
    rescue ArgumentError
      raise
    rescue => e
      log_error("Failed to update mappings: #{e.message}")

      {
        status: :error,
        message: "Failed to update mappings: #{e.message}",
        error: e.class.name,
        backtrace: e.backtrace.first(5)
      }
    end

    # Retrieves the current mappings for this index
    #
    # @return [Hash] The index mappings including field types and properties
    # @raise [OpenSearchError] If fetching mappings fails
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/get-mapping/
    # @example Get index mappings
    #   mappings = index.mappings
    #   properties = mappings[index.name]["mappings"]["properties"]
    def mappings
      client.indices.get_mapping(index: name)
    rescue => e
      log_error("Failed to fetch mappings: #{e.message}")
      raise OpenSearchError, "Failed to fetch index mappings: #{e.message}"
    end

    # Deletes this index from OpenSearch
    #
    # WARNING: This operation is destructive and cannot be undone.
    # All documents and settings in the index will be permanently removed.
    #
    # @return [Hash] The response from OpenSearch confirming deletion
    # @raise [OpenSearchError] If deletion fails
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/delete-index/
    # @example Delete an index
    #   index.delete!
    def delete!
      log_info("Deleting index: #{name}")
      client.indices.delete(index: name)
    rescue => e
      log_error("Failed to delete index: #{e.message}")
      raise OpenSearchError, "Failed to delete index '#{name}': #{e.message}"
    end

    # Returns the number of documents in this index
    #
    # @return [Integer] The total count of documents in the index
    # @raise [OpenSearchError] If count operation fails
    # @see https://docs.opensearch.org/latest/api-reference/count/
    # @example Get document count
    #   count = index.count
    #   puts "Index has #{count} documents"
    def count
      response = client.count(index: name)
      response["count"].to_i
    rescue => e
      log_error("Failed to count documents: #{e.message}")
      raise OpenSearchError, "Failed to count documents in index '#{name}': #{e.message}"
    end

    # Retrieves all aliases for this index
    #
    # @return [Array<String>] The aliases for this index (may be empty)
    # @raise [OpenSearchError] If fetching aliases fails
    # @see https://docs.opensearch.org/latest/api-reference/alias/
    # @example Get index aliases
    #   aliases = index.aliases
    #   # => ["alias1", "alias2"]
    def aliases
      response = client.indices.get_alias(index: name)
      response.dig(name, "aliases")&.keys || []
    rescue => e
      log_error("Failed to fetch aliases: #{e.message}")
      raise OpenSearchError, "Failed to fetch aliases for index '#{name}': #{e.message}"
    end

    # Creates an alias for this index
    #
    # @param alias_name [String] The new alias for the index
    # @return [Array<String>] The complete list of aliases for this index
    # @raise [ArgumentError] If alias_name is nil or empty
    # @raise [OpenSearchError] If alias creation fails
    # @see https://docs.opensearch.org/latest/api-reference/alias/
    # @example Create an alias
    #   index.create_alias("my-alias")
    #   # => ["my-alias"]
    def create_alias(alias_name)
      raise ArgumentError, "Alias name cannot be nil" if alias_name.nil?
      raise ArgumentError, "Alias name cannot be empty" if alias_name.to_s.strip.empty?

      log_info("Creating alias '#{alias_name}' for index: #{name}")
      client.indices.put_alias(index: name, name: alias_name)
      aliases
    rescue => e
      log_error("Failed to create alias: #{e.message}")
      raise OpenSearchError, "Failed to create alias '#{alias_name}': #{e.message}"
    end

    # Gets all analyzers available for this index
    #
    # Includes analyzers defined at the cluster level as well as those defined
    # for this particular index.
    #
    # @return [Array<String>] List of analyzer names available for this index
    # @raise [OpenSearchError] If fetching analyzers fails
    # @see https://docs.opensearch.org/latest/analyzers/index/
    # @example Get available analyzers
    #   analyzers = index.all_available_analyzers
    #   # => ["standard", "simple", "my_custom_analyzer"]
    def all_available_analyzers
      settings_response = settings
      index_analyzers = settings_response.dig(name, "settings", "index", "analysis", "analyzer")&.keys || []
      cluster_analyzers = client.cluster.get_settings.dig("persistent", "index", "analysis", "analyzer")&.keys || []

      (index_analyzers + cluster_analyzers).uniq
    rescue => e
      log_error("Failed to fetch analyzers: #{e.message}")
      raise OpenSearchError, "Failed to fetch analyzers for index '#{name}': #{e.message}"
    end

    alias_method :analyzers, :all_available_analyzers

    # Analyzes text using a specific analyzer from this index
    #
    # Returns the tokens that would be created by putting the provided string into the
    # given analyzer. This is useful for testing and debugging analyzers.
    #
    # @param analyzer [String] Name of the analyzer to use (must exist in index settings)
    # @param text [String] The text to analyze
    # @return [Array<String>] A list of tokens produced by the analyzer
    # @raise [ArgumentError] If analyzer or text is nil/empty
    # @raise [ArgumentError] If the analyzer does not exist in the index
    # @raise [OpenSearchError] If the analyze operation fails
    # @see https://docs.opensearch.org/latest/api-reference/analyze-apis/
    # @see https://docs.opensearch.org/latest/analyzers/index/
    # @example Analyze text with a custom analyzer
    #   tokens = index.analyze_text(analyzer: "my_analyzer", text: "Hello World")
    #   # => ["hello", "world"]
    def analyze_text(analyzer:, text:)
      raise ArgumentError, "Analyzer cannot be nil" if analyzer.nil?
      raise ArgumentError, "Analyzer cannot be empty" if analyzer.to_s.strip.empty?
      raise ArgumentError, "Text cannot be nil" if text.nil?

      # Verify analyzer exists
      settings_response = settings
      unless settings_response.dig(name, "settings", "index", "analysis", "analyzer", analyzer)
        raise ArgumentError, "Analyzer '#{analyzer}' does not exist in index '#{name}'"
      end

      # Analyze the text
      response = client.indices.analyze(
        index: name,
        body: {
          analyzer:,
          text:
        }
      )

      # Extract tokens from response
      response["tokens"]&.map { |token| token["token"] } || []
    rescue ArgumentError
      raise
    rescue => e
      log_error("Failed to analyze text: #{e.message}")
      raise OpenSearchError, "Failed to analyze text: #{e.message}"
    end

    # Analyzes text using the analyzer associated with a specific field
    #
    # This method determines which analyzer to use based on the field's mapping,
    # then analyzes the text. This is useful for testing how text will be
    # tokenized when indexed into a specific field.
    #
    # @param field [String] The field name whose analyzer should be used
    # @param text [String] The text to analyze
    # @return [Array<String>] A list of tokens produced by the field's analyzer
    # @raise [ArgumentError] If field or text is nil/empty
    # @raise [ArgumentError] If the field does not exist in the index mappings
    # @raise [ArgumentError] If no analyzer is specified for the field
    # @raise [OpenSearchError] If the analyze operation fails
    # @see #analyze_text
    # @see https://docs.opensearch.org/latest/api-reference/analyze-apis/
    # @example Analyze text using a field's analyzer
    #   tokens = index.analyze_text_field(field: "title", text: "Quick Brown Fox")
    def analyze_text_field(field:, text:)
      raise ArgumentError, "Field cannot be nil" if field.nil?
      raise ArgumentError, "Field cannot be empty" if field.to_s.strip.empty?
      raise ArgumentError, "Text cannot be nil" if text.nil?

      mappings_response = mappings
      field_mapping = mappings_response.dig(name, "mappings", "properties", field)

      unless field_mapping
        raise ArgumentError, "Field '#{field}' does not exist in index '#{name}'"
      end

      analyzer = field_mapping["analyzer"]
      unless analyzer
        raise ArgumentError, "No analyzer specified for field '#{field}'"
      end

      analyze_text(analyzer:, text:)
    end

    # Deletes a document from this index by its ID
    #
    # @param id [String] The ID of the document to delete
    # @return [Hash] The response from OpenSearch containing deletion status
    # @raise [ArgumentError] If the document ID is nil or empty
    # @raise [OpenSearchError] If the delete operation fails
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/delete-document/
    # @example Delete a document
    #   result = index.delete_by_id("doc123")
    #   puts "Deleted: #{result['result']}" # => "deleted"
    def delete_by_id(id)
      raise ArgumentError, "Document ID cannot be nil" if id.nil?
      raise ArgumentError, "Document ID cannot be empty" if id.to_s.strip.empty?

      log_debug("Deleting document with ID: #{id}")
      client.delete(index: name, id:)
    rescue ArgumentError
      raise
    rescue => e
      log_error("Failed to delete document '#{id}': #{e.message}")
      raise OpenSearchError, "Failed to delete document: #{e.message}"
    end

    # Deletes all documents from this index
    #
    # This method executes a delete_by_query with a match_all query to remove all documents.
    # The index structure (mappings and settings) remains intact.
    #
    # WARNING: This operation is destructive and cannot be undone.
    #
    # @return [Integer] The number of documents that were deleted
    # @raise [OpenSearchError] If the clear operation fails
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/delete-by-query/
    # @example Clear all documents from an index
    #   index = client["my_index"]
    #   deleted_count = index.clear! # Deletes all documents and returns count
    #   puts "Deleted #{deleted_count} documents"
    def clear!
      log_warn("Clearing all documents from index: #{name}")

      response = client.delete_by_query(
        index: name,
        body: {
          query: {
            match_all: {}
          }
        }
      )

      deleted = response["deleted"].to_i
      log_info("Deleted #{deleted} documents from index: #{name}")
      deleted
    rescue => e
      log_error("Failed to clear index: #{e.message}")
      raise OpenSearchError, "Failed to clear index '#{name}': #{e.message}"
    end

    # Indexes a single document into this index
    #
    # @param doc [Hash] The document to index
    # @param id [String, nil] The unique identifier for the document (auto-generated if nil)
    # @param refresh [Boolean, String] Whether to refresh after indexing (default: false)
    # @return [Hash] The response from OpenSearch
    # @raise [ArgumentError] If doc is not a Hash
    # @raise [OpenSearchError] If the index operation fails
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/index-document/
    # @example Index a document with auto-generated ID
    #   response = index.index_document({ title: "My Document", content: "Hello" })
    # @example Index a document with specific ID
    #   response = index.index_document({ title: "My Document" }, id: "doc1")
    def index_document(doc, id: nil, refresh: false)
      raise ArgumentError, "Document must be a Hash" unless doc.is_a?(Hash)
      raise ArgumentError, "Document cannot be empty" if doc.empty?

      params = {index: name, body: doc}
      params[:id] = id if id
      params[:refresh] = refresh if refresh

      log_debug("Indexing document#{id ? " with ID: #{id}" : ""}")
      client.index(**params)
    rescue ArgumentError
      raise
    rescue => e
      log_error("Failed to index document: #{e.message}")
      raise OpenSearchError, "Failed to index document: #{e.message}"
    end

    # Bulk indexes documents from a JSONL (JSON Lines) file
    #
    # @param filename [String] Path to the JSONL file containing documents to index
    # @param id_field [String, nil] Field name to use as document ID (optional)
    # @param refresh [Boolean, String] Whether to refresh after bulk operation (default: false)
    # @return [Hash] The response from OpenSearch bulk operation with success/failure counts
    # @raise [ArgumentError] If filename is nil/empty or file doesn't exist
    # @raise [OpenSearchError] If the bulk operation fails
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/bulk/
    # @example Bulk index from JSONL file
    #   result = index.index_jsonl("documents.jsonl")
    #   puts "Indexed #{result['items'].count} documents"
    def index_jsonl(filename, id_field: nil, refresh: false)
      raise ArgumentError, "Filename cannot be nil" if filename.nil?
      raise ArgumentError, "Filename cannot be empty" if filename.to_s.strip.empty?
      raise ArgumentError, "File not found: #{filename}" unless File.exist?(filename)

      log_info("Bulk indexing from file: #{filename}")

      body = []
      File.foreach(filename) do |line|
        next if line.strip.empty?

        doc = JSON.parse(line)
        action = {index: {_index: name}}
        action[:index][:_id] = doc.delete(id_field) if id_field && doc[id_field]

        body << action
        body << doc
      end

      return {items: [], errors: false} if body.empty?

      response = client.bulk(body:, refresh:)

      log_info("Bulk index complete: #{response["items"]&.count || 0} operations")
      response
    rescue ArgumentError
      raise
    rescue JSON::ParserError => e
      log_error("Invalid JSON in file '#{filename}': #{e.message}")
      raise ArgumentError, "Invalid JSON in file: #{e.message}"
    rescue => e
      log_error("Failed to bulk index from file: #{e.message}")
      raise OpenSearchError, "Failed to bulk index: #{e.message}"
    end

    private

    # Builds the index body for index creation
    #
    # @param knn [Boolean] Whether to enable k-NN
    # @param settings [Hash, nil] Additional settings
    # @return [Hash] Index body configuration
    # @api private
    def self.build_index_body(knn:, settings:)
      body = {settings: {index: {}}}
      body[:settings][:index][:knn] = knn

      if settings
        body[:settings][:index].merge!(settings)
      end

      body
    end

    # Initializes a new Index instance
    #
    # This is a private constructor. Use {.open} or {.create} instead.
    #
    # @param client [OpenSearch::Sugar::Client] The client instance
    # @param name [String] The index name
    # @api private
    def initialize(client:, name:)
      @client = client
      @name = name
    end

    # Returns the logger instance from the client
    #
    # @return [Logger] The logger instance
    # @api private
    def logger = client.logger

    # Extracts settings or mappings from a hash
    #
    # @param hash [Hash] The hash to extract from
    # @param key [String] The key to extract
    # @return [Hash] Extracted settings
    # @api private
    def extract_settings(hash, key)
      if hash.keys.map(&:to_s) == [key]
        hash.values.first
      else
        hash
      end
    end

    # Helper method to safely reopen an index if it's closed
    #
    # @return [void]
    # @api private
    def reopen_index
      status = client.indices.status(index: name)
      state = status.dig("indices", name, "state")

      if state == "close"
        log_info("Reopening closed index: #{name}")
        client.indices.open(index: name)
      end
    rescue => e
      log_warn("Failed to reopen index: #{e.message}")
    end

    # Logs an info message
    #
    # @param message [String] The message to log
    # @api private
    def log_info(message) = logger.info("OpenSearch::Sugar::Index[#{name}] - #{message}")

    # Logs a debug message
    #
    # @param message [String] The message to log
    # @api private
    def log_debug(message) = logger.debug("OpenSearch::Sugar::Index[#{name}] - #{message}")

    # Logs a warning message
    #
    # @param message [String] The message to log
    # @api private
    def log_warn(message) = logger.warn("OpenSearch::Sugar::Index[#{name}] - #{message}")

    # Logs an error message
    #
    # @param message [String] The message to log
    # @api private
    def log_error(message) = logger.error("OpenSearch::Sugar::Index[#{name}] - #{message}")
  end
end
