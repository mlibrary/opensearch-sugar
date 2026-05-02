# frozen_string_literal: true

require "delegate"
require "opensearch-ruby"
require_relative "models"
require "httpx/adapters/faraday"

module OpenSearch::Sugar
  # A wrapper around +OpenSearch::Client+ (via +SimpleDelegator+) that adds
  # index management helpers and object-oriented access to indices and ML models.
  #
  # All methods of the underlying +OpenSearch::Client+ are available directly on
  # this object via delegation. Sugar-specific additions are documented below.
  #
  # @example Connect and work with an index
  #   client = OpenSearch::Sugar::Client.new
  #   index  = client["my_index"]
  #   index.count #=> 0
  #
  # @see OpenSearch::Sugar::Index
  # @see OpenSearch::Sugar::Models
  class Client < SimpleDelegator
    # Creates a new raw OpenSearch client instance
    #
    # @param args [Array] Arguments to pass to the OpenSearch::Client constructor
    # @param kwargs [Hash] Keyword arguments to pass to the OpenSearch::Client constructor
    # @return [OpenSearch::Client] A new raw client instance
    def self.raw_client(*args, **kwargs)
      ::OpenSearch::Client.new(*args, **kwargs)
    end

    # The underlying raw +OpenSearch::Client+ instance, bypassing the Sugar wrapper.
    # @return [OpenSearch::Client]
    attr_reader :raw_client

    # The {OpenSearch::Sugar::Models} instance for ML model management on this cluster.
    # @return [OpenSearch::Sugar::Models]
    attr_reader :models

    # Creates a new {OpenSearch::Sugar::Client}.
    #
    # Falls back to environment variables if keyword arguments are omitted:
    # - +host+ — +OPENSEARCH_URL+ → +OPENSEARCH_HOST+ → +"https://localhost:9000"+
    # - +user+ — +OPENSEARCH_USER+ → +"admin"+
    # - +password+ — +OPENSEARCH_PASSWORD+ → +OPENSEARCH_INITIAL_ADMIN_PASSWORD+
    #
    # All keyword arguments are merged with {#default_args}, with explicit kwargs taking
    # precedence.
    #
    # @param host [String] OpenSearch base URL
    # @param kwargs [Hash] Additional keyword arguments forwarded to +OpenSearch::Client.new+
    # @see https://github.com/opensearch-project/opensearch-ruby OpenSearch Ruby client
    # @example Connect using environment variables
    #   client = OpenSearch::Sugar::Client.new
    # @example Connect to a specific host
    #   client = OpenSearch::Sugar::Client.new(host: "https://search.example.com:9200")
    def initialize(host: ENV["OPENSEARCH_URL"] || ENV["OPENSEARCH_HOST"] || "https://localhost:9000", **kwargs)
      kwargs[:host] = host
      args = default_args.merge(kwargs)
      @raw_client = self.class.raw_client(**args)
      __setobj__(@raw_client)
      @models = Models.new(self)
    end

    # Returns the default connection arguments used when building the underlying client.
    #
    # Values are drawn from environment variables where available:
    # - +:user+ — +OPENSEARCH_USER+ (default: +"admin"+)
    # - +:password+ — +OPENSEARCH_PASSWORD+ or +OPENSEARCH_INITIAL_ADMIN_PASSWORD+
    # - +:host+ — +OPENSEARCH_URL+ (default: +"https://localhost:9000"+)
    # - +:retry_on_failure+ — 5
    # - +:request_timeout+ — 5 seconds
    # - +:log+ — +true+
    # - +:trace+ — +false+
    # - +:transport_options+ — SSL verification disabled
    #
    # @return [Hash{Symbol => Object}] Default keyword arguments for +OpenSearch::Client.new+
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

    # Sets a cluster-wide log level via the OpenSearch dynamic settings API.
    #
    # Writes a persistent cluster setting, so the change survives restarts.
    #
    # @param logger [String] The logger name to configure (default: +"logger._root"+)
    # @param level [String] Log level — one of +"trace"+, +"debug"+, +"info"+, +"warn"+, +"error"+ (default: +"warn"+)
    # @return [Hash] The OpenSearch response
    # @see https://docs.opensearch.org/latest/install-and-configure/configuring-opensearch/logs/ OpenSearch logging docs
    # @example Silence most cluster noise
    #   client.set_log_level(level: "error")
    # @example Set a specific logger
    #   client.set_log_level(logger: "logger.org.opensearch.discovery", level: "debug")
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

    # Returns the names of all non-system indices in the cluster.
    #
    # @return [Array<String>] Index names
    # @example
    #   client.index_names #=> ["products", "orders", "users"]
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

    # Opens an existing index or creates it if it does not exist.
    #
    # @param index_name [String] The name of the index
    # @return [OpenSearch::Sugar::Index]
    def open_or_create_index(index_name)
      Index.open(client: self, name: index_name)
    rescue ArgumentError
      Index.create(client: self, name: index_name)
    end

    # Deletes an index by name.
    #
    # @param index_name [String] The name of the index to delete
    # @return [Hash] The OpenSearch acknowledgement response
    # @raise [OpenSearch::Transport::Transport::Errors::NotFound] if the index does not exist
    def delete_index!(index_name)
      indices.delete(index: index_name)
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

    # Tests a custom "transient" analyzer defined inline by its components, without
    # requiring the analyzer to be registered on any index. This is useful for
    # prototyping and iterating on analyzer configurations before committing them to
    # index settings.
    #
    # Sends the definition directly to the cluster-level +/_analyze+ endpoint, so no
    # index is involved. You must supply at least a +tokenizer+. The +filter+ (token
    # filters) and +char_filter+ (character filters) keys are optional.
    #
    # @param text [String] The text to analyze
    # @param tokenizer [String] The tokenizer to use (e.g. +"standard"+, +"keyword"+)
    # @param filter [Array<String, Hash>] Optional token filters to apply in order
    #   (e.g. +["lowercase", "asciifolding"]+)
    # @param char_filter [Array<String, Hash>] Optional character filters to apply
    #   before tokenization (e.g. +["html_strip"]+)
    # @return [Array<String, Array<String>>] A list of tokens produced by the transient
    #   analyzer. If multiple tokens share a position in the token stream (e.g. from a
    #   synonym filter), they are grouped as a nested Array.
    # @raise [ArgumentError] If +tokenizer+ is nil or empty
    # @see OpenSearch::Sugar::Index#test_analyzer_by_name For testing a named analyzer
    #   that is already registered on a specific index.
    # @see OpenSearch::Sugar::Index#test_analyzer_by_fieldname For testing the analyzer
    #   configured on a specific index field.
    # @see https://docs.opensearch.org/latest/api-reference/analyze-apis/#apply-a-custom-transient-analyzer
    #   OpenSearch Analyze API — Apply a custom transient analyzer
    # @example Basic transient analyzer
    #   client.test_analyzer_by_definition(
    #     text: "Hello, World!",
    #     tokenizer: "standard",
    #     filter: ["lowercase"]
    #   )
    #   #=> ["hello", "world"]
    # @example With a character filter
    #   client.test_analyzer_by_definition(
    #     text: "<b>Hello</b>",
    #     tokenizer: "standard",
    #     char_filter: ["html_strip"],
    #     filter: ["lowercase"]
    #   )
    #   #=> ["hello"]
    def test_analyzer_by_definition(text:, tokenizer:, filter: [], char_filter: [])
      raise ArgumentError, "tokenizer cannot be nil or empty" if tokenizer.nil? || tokenizer.to_s.empty?

      body = {tokenizer: tokenizer, text: text}
      body[:filter] = filter if filter && !filter.empty?
      body[:char_filter] = char_filter if char_filter && !char_filter.empty?

      response = self.indices.analyze(body: body)

      tokens = response["tokens"]
      tokens.each_with_index.map do |token, i|
        if i > 0 && token["position"] == tokens[i - 1]["position"]
          [token["token"]]
        else
          token["token"]
        end
      end
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
      warn "Warning: Failed to reopen index #{index_name}: #{open_error.message}"
    end
  end
end
