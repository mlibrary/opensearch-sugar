# frozen_string_literal: true

require_relative "client"

module OpenSearch::Sugar
  class Index
    # @return OpenSearch::Sugar::Client
    attr_accessor :client

    attr_accessor :name

    # Opens an existing OpenSearch index
    #
    # This method verifies that the index exists before opening it.
    #
    # @param client [OpenSearch::Sugar::Client] The client instance to use for accessing the index
    # @param name [String] The name of the index to open
    # @return [OpenSearch::Sugar::Index] A new Index instance for the existing index
    # @raise [ArgumentError] If the index does not exist
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/exists/
    # @example Open an existing index
    #   index = OpenSearch::Sugar::Index.open(client: client, name: "my-index")
    def self.open(client:, name:)
      raise ArgumentError, "Index #{name} not found" unless client.indices.exists?(index: name)
      new(client: client, name: name)
    end

    # Creates a new OpenSearch index
    #
    # This method creates a new index with the specified name and optional settings.
    # By default, k-NN (k-nearest neighbors) is enabled for vector search capabilities.
    #
    # @param client [OpenSearch::Sugar::Client] The client instance to use for creating the index
    # @param name [String] The name of the index to create
    # @param knn [Boolean] Whether to enable k-NN (k-nearest neighbors) support (default: true)
    # @return [OpenSearch::Sugar::Index] A new Index instance for the created index
    # @raise [ArgumentError] If the index already exists
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/create-index/
    # @see https://docs.opensearch.org/latest/search-plugins/knn/index/
    # @example Create a new index with k-NN enabled
    #   index = OpenSearch::Sugar::Index.create(client: client, name: "my-index")
    # @example Create a new index without k-NN
    #   index = OpenSearch::Sugar::Index.create(client: client, name: "my-index", knn: false)
    def self.create(client:, name:, knn: true)
      raise ArgumentError.new("Index #{name} already exists") if client.indices.exists?(index: name)
      client.indices.create(index: name, body: {settings: {index: {knn: knn}}})
      new(client: client, name: name)
    end

    # Updates the settings for this index
    #
    # This is a convenience method that delegates to the client's update_settings method.
    # The index will be closed, settings applied, and then reopened.
    #
    # @param settings [Hash] The settings to update
    # @return [Hash] A result hash with status, message, and metadata
    # @see OpenSearch::Sugar::Client#update_settings
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
      client.update_settings(settings, name)
    end

    # Retrieves the current settings for this index
    #
    # @return [Hash] The index settings including analysis, number of shards, replicas, etc.
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/get-settings/
    # @example Get index settings
    #   settings = index.settings
    #   puts settings[index.name]["settings"]["index"]["number_of_shards"]
    def settings
      client.indices.get_settings(index: name)
    end

    # Updates the mappings for this index
    #
    # This is a convenience method that delegates to the client's update_mappings method.
    # The index will be closed, mappings applied, and then reopened.
    #
    # @param mappings [Hash] The mappings to update
    # @return [Hash] A result hash with status, message, and metadata
    # @see OpenSearch::Sugar::Client#update_mappings
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
      client.update_mappings(mappings, name)
    end

    # Retrieves the current mappings for this index
    #
    # @return [Hash] The index mappings including field types and properties
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/get-mapping/
    # @example Get index mappings
    #   mappings = index.mappings
    #   properties = mappings[index.name]["mappings"]["properties"]
    def mappings
      client.indices.get_mapping(index: name)
    end

    # Deletes this index from OpenSearch
    #
    # WARNING: This operation is destructive and cannot be undone.
    # All documents and settings in the index will be permanently removed.
    #
    # @return [Hash] The response from OpenSearch confirming deletion
    # @see https://docs.opensearch.org/latest/api-reference/index-apis/delete-index/
    # @example Delete an index
    #   index.delete!
    def delete!
      client.indices.delete(index: name)
    end

    # Returns the number of documents in this index
    #
    # @return [Integer] The total count of documents in the index
    # @see https://docs.opensearch.org/latest/api-reference/count/
    # @example Get document count
    #   count = index.count
    #   puts "Index has #{count} documents"
    def count
      response = client.count(index: name)
      response["count"].to_i
    end

    # Get a (potentially empty) list of aliases of this index
    # @return [Array<String>] The aliases for this index
    def aliases
      response = client.indices.get_alias(index: name)
      response.dig(name, "aliases")&.keys || []
    end

    # Create an alias for this index with the given name
    # @param alias_name [String] the new alias for the index
    # @return [Array<String>] the complete list of aliases for this index
    def create_alias(alias_name)
      client.indices.put_alias(index: name, name: alias_name)
      aliases
    end

    # Get a list of all named analyzers available in this index for use when indexing
    # Include those defined at the cluster level as well as those defined for this
    # particular index
    # @return [Array<String>] List of analyzer names available for this index
    def all_available_analyzers
      settings_response = settings
      index_analyzers = settings_response.dig(name, "settings", "index", "analysis", "analyzer")&.keys || []
      cluster_analyzers = client.cluster.get_settings.dig("persistent", "index", "analysis", "analyzer")&.keys || []

      (index_analyzers + cluster_analyzers).uniq
    end

    alias_method :analyzers, :all_available_analyzers

    # Analyzes text using a specific analyzer from this index
    #
    # Returns the tokens that would be created by putting the provided string into the
    # given analyzer. This is useful for testing and debugging analyzers.
    #
    # @param analyzer [String] Name of the analyzer to use (must exist in index settings)
    # @param text [String] The text to analyze
    # @return [Array<String, Array<String>>] A list of tokens produced by the
    #   targeted analyzer. If multiple tokens exist at the same point in the token
    #   stream, they are provided as an array.
    # @raise [ArgumentError] If the analyzer does not exist in the index
    # @see https://docs.opensearch.org/latest/api-reference/analyze-apis/
    # @see https://docs.opensearch.org/latest/analyzers/index/
    # @example Analyze text with a custom analyzer
    #   tokens = index.analyze_text(analyzer: "my_analyzer", text: "Hello World")
    #   # => ["hello", "world"]
    def analyze_text(analyzer:, text:)
      # Check if analyzer exists in index settings
      settings_response = settings
      unless settings_response.dig(name, "settings", "index", "analysis", "analyzer", analyzer)
        raise ArgumentError, "Analyzer '#{analyzer}' does not exist in index '#{name}'"
      end

      # Analyze the text
      response = client.indices.analyze(
        index: name,
        body: {
          analyzer: analyzer,
          text: text
        }
      )

      # Process tokens from response
      response["tokens"].map do |token|
        # If position is same as previous token, group them
        if token["position"] == response["tokens"][response["tokens"].index(token) - 1]&.dig("position")
          [token["token"]]
        else
          token["token"]
        end
      end
    end

    # Analyzes text using the analyzer associated with a specific field
    #
    # This method determines which analyzer to use based on the field's mapping,
    # then analyzes the text exactly as in #analyze_text. This is useful for testing
    # how text will be tokenized when indexed into a specific field.
    #
    # @param field [String] The field name whose analyzer should be used
    # @param text [String] The text to analyze
    # @return [Array<String, Array<String>>] A list of tokens produced by the field's analyzer
    # @raise [ArgumentError] If the field does not exist in the index mappings
    # @raise [ArgumentError] If no analyzer is specified for the field
    # @see #analyze_text
    # @see https://docs.opensearch.org/latest/api-reference/analyze-apis/
    # @example Analyze text using a field's analyzer
    #   tokens = index.analyze_text_field(field: "title", text: "Quick Brown Fox")
    def analyze_text_field(field:, text:)
      mappings_response = mappings
      field_mapping = mappings_response.dig(name, "mappings", "properties", field)
      raise ArgumentError, "Field '#{field}' does not exist in index '#{name}'" unless field_mapping

      analyzer = field_mapping["analyzer"]
      raise ArgumentError, "No analyzer specified for field '#{field}'" unless analyzer

      analyze_text(analyzer: analyzer, text: text)
    end

    # Deletes a document from this index by its ID
    #
    # @param id [String] The ID of the document to delete
    # @return [Hash] The response from OpenSearch containing deletion status
    # @raise [ArgumentError] If the document ID is nil or empty
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/delete-document/
    # @example Delete a document
    #   result = index.delete_by_id("doc123")
    #   puts "Deleted: #{result['result']}" # => "deleted"
    def delete_by_id(id)
      raise ArgumentError, "Document ID cannot be nil or empty" if id.nil? || id.empty?
      client.delete(index: name, id: id)
    end

    # Deletes all documents from this index
    #
    # This method executes a delete_by_query with a match_all query to remove all documents.
    # The index structure (mappings and settings) remains intact.
    #
    # WARNING: This operation is destructive and cannot be undone.
    #
    # @return [Integer] The number of documents that were deleted
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/delete-by-query/
    # @example Clear all documents from an index
    #   index = client["my_index"]
    #   deleted_count = index.clear! # Deletes all documents and returns count
    #   puts "Deleted #{deleted_count} documents"
    def clear!
      response = client.delete_by_query(
        index: name,
        body: {
          query: {
            match_all: {}
          }
        }
      )
      response["deleted"].to_i
    end

    # Indexes a single document into this index
    #
    # @param doc [Hash] The document to index
    # @param uid [String] The unique identifier for the document
    # @return [Hash] The response from OpenSearch (method currently unimplemented)
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/index-document/
    # @note This method is currently a stub and needs to be implemented
    def index_document(doc, uid)
    end

    # Bulk indexes documents from a JSONL (JSON Lines) file
    #
    # @param filename [String] Path to the JSONL file containing documents to index
    # @return [Hash] The response from OpenSearch bulk operation (method currently unimplemented)
    # @see https://docs.opensearch.org/latest/api-reference/document-apis/bulk/
    # @note This method is currently a stub and needs to be implemented
    def index_jsonl(filename)
    end

    private

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
      # client.indices.create(index: name, body: default_index_body)
      # client[name]
    end

    # Returns the default index body configuration
    #
    # @return [Hash] Default settings for index creation
    # @api private
    def default_index_body
      {
        settings: {
          index: {
            number_of_shards: 2
          }
        }
      }
    end
  end
end
