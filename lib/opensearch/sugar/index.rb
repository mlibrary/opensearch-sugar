# frozen_string_literal: true

require "json"
require_relative "client"

module OpenSearch::Sugar
  class Index
    # @return OpenSearch::Sugar::Client
    attr_accessor :client

    attr_accessor :name

    # @param client [OpenSearch::Sugar::Client]
    def self.open(client:, name:)
      raise ArgumentError, "Index #{name} not found" unless client.has_index?(name)
      new(client: client, name: name)
    end

    def self.create(client:, name:, knn: true)
      raise ArgumentError.new("Index #{name} already exists") if client.has_index?(name)
      client.indices.create(index: name, body: {settings: {index: {knn: knn}}})
      new(client: client, name: name)
    end

    def update_settings(settings)
      client.update_settings(settings, name)
    end

    def settings
      client.indices.get_settings(index: name)
    end

    def update_mappings(mappings)
      client.update_mappings(mappings, name)
    end

    def mappings
      client.indices.get_mapping(index: name)
    end

    def delete!
      client.indices.delete(index: name)
    end

    # Forces a refresh of this index, making all recently indexed documents
    # immediately visible to searches. Useful in tests and after bulk indexing.
    #
    # @return [Hash] The OpenSearch response
    def refresh
      client.indices.refresh(index: name)
    end

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

    # Return the tokens that would be created by putting the provided string into the
    # given analyzer
    # @param analyzer [String] Name of the analyzer
    # @param text [String] the text to analyzer
    # @return [Array<String, Array<String>>] A list of tokens produced by the
    #   targeted analyzer. If multiple tokens exist at the same point in the token
    #   stream, provide them as an array.
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

      # Process tokens from response, grouping same-position tokens as arrays
      tokens = response["tokens"]
      tokens.each_with_index.map do |token, i|
        if i > 0 && token["position"] == tokens[i - 1]["position"]
          [token["token"]]
        else
          token["token"]
        end
      end
    end

    # Analyze text exact as in #analyze_text, but take a field name that can be used
    # to determine which analyzer to run. Throw an error if the field does not exist either
    # as an explicit or a dynamic mapping. Call #analyze_text to do the actual work.
    def analyze_text_field(field:, text:)
      mappings_response = mappings
      field_mapping = mappings_response.dig(name, "mappings", "properties", field)
      raise ArgumentError, "Field '#{field}' does not exist in index '#{name}'" unless field_mapping

      analyzer = field_mapping["analyzer"]
      raise ArgumentError, "No analyzer specified for field '#{field}'" unless analyzer

      analyze_text(analyzer: analyzer, text: text)
    end

    # Deletes the document with the given ID from this index
    #
    # @param id [String] The ID of the document to delete
    # @return [Hash] The response from OpenSearch containing deletion status
    # @raise [ArgumentError] If the document ID is nil or empty
    def delete_by_id(id)
      raise ArgumentError, "Document ID cannot be nil or empty" if id.nil? || id.empty?
      client.delete(index: name, id: id)
    end

    # Delete all documents from this index by executing a delete_by_query with match_all query.
    # @return [Integer] The number of documents that were deleted
    # @example
    #   index = client["my_index"]
    #   deleted_count = index.clear! # Deletes all documents and returns count
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

    # Index a single document into this index.
    #
    # This method is intentionally simple and inefficient — it issues one HTTP request
    # per document. For bulk loading, use the raw +client.bulk+ API instead.
    #
    # @todo Replace with a bulk-API implementation for large-scale use.
    #
    # @param doc [Hash] The document body to index
    # @param id [String] The document ID (_id in OpenSearch)
    # @return [Hash] The OpenSearch response
    def index_document(doc, id)
      # TODO: inefficient for large-scale use; implement bulk upload API
      client.index(index: name, id: id, body: doc)
    end

    # Index all documents from a JSONL (newline-delimited JSON) file or IO-like object.
    #
    # Each line must be a valid JSON object. The value of +id_field+ in each document
    # is used as the document ID. Raises +ArgumentError+ if any line is missing the
    # specified field.
    #
    # Accepts a file path (String) or any IO-like object (e.g. +File+, +StringIO+),
    # which makes it straightforward to test without touching the filesystem.
    #
    # This method is intentionally simple and inefficient — it calls +#index_document+
    # once per line. For bulk loading, use the raw +client.bulk+ API instead.
    #
    # @todo Replace with a bulk-API implementation for large-scale use.
    #
    # @param source [String, #each_line] A file path or an IO-like object
    # @param id_field [Symbol, String] The key in each document to use as the document ID
    # @return [void]
    # @raise [ArgumentError] If a document does not contain the specified +id_field+
    def index_jsonl_file(source, id_field:)
      # TODO: inefficient for large-scale use; implement bulk upload API
      io = source.is_a?(String) ? File.open(source) : source
      io.each_line do |line|
        doc = JSON.parse(line, symbolize_names: true)
        id = doc.fetch(id_field.to_sym) {
          raise ArgumentError, "id_field :#{id_field} not found in document: #{line.chomp}"
        }
        index_document(doc, id.to_s)
      end
    end

    private

    def initialize(client:, name:)
      @client = client
      @name = name
      # client.indices.create(index: name, body: default_index_body)
      # client[name]
    end

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
