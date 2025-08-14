# frozen_string_literal: true

require "opensearch-ruby"

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

    attr_reader :raw_client
    # Creates a new OpenSearch::Sugar::Client instance
    #
    # @param host [String] The OpenSearch host to connect to
    # @param kwargs [Hash] Additional arguments to pass to the OpenSearch::Client constructor
    # @return [OpenSearch::Sugar::Client] A new client instance
    # @see [OpenSearch::Client]
    def initialize(host:, **kwargs)
      kwargs[:host] = host
      args = default_args.merge(kwargs)
      @raw_client = self.class.raw_client(**args)
      __setobj__(@raw_client)
    end

    # Returns the default arguments for the OpenSearch client
    #
    # @return [Hash] The default connection arguments
    def default_args
      {
        retry_on_failure: 5,
        request_timeout: 5,
        log: true,
        transport_options: {ssl: {verify: false}}
      }
    end

    # Checks if an index exists in OpenSearch
    #
    # @param name [String] The name of the index to check
    # @return [Boolean] True if the index exists, false otherwise
    def has_index?(name)
      indices.exists?(index: name)
    end

    # Retrieves an index by name
    #
    # @param index_name [String] The name of the index to retrieve
    # @return [OpenSearch::Sugar::Index] The index instance
    def [](index_name)
      Index.open(self, index_name)
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
    # @return [Hash] A result hash with status, message, and metadata
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
    #     },
    #     metadata: {
    #       description: "Custom analyzer settings"
    #     }
    #   }
    #
    #   result = client.upload_settings(settings, index: "my_index")
    #   if result[:status] == "success"
    #     puts "Settings updated: #{result[:message]}"
    #   else
    #     puts "Error: #{result[:message]}"
    #   end
    def upload_settings(settings, index_name)
      # Extract the actual OpenSearch settings from our enhanced settings object
      opensearch_settings = {settings: settings[:settings]}

      indices.close(index: index_name)
      indices.put_settings(index: index_name, body: opensearch_settings[:settings])
      indices.open(index: index_name)

      {
        status: "success",
        message: "Updated settings for index #{index_name}",
        metadata: settings[:metadata]
      }
    rescue => e
      # Try to reopen the index if it's closed
      reopen_index(index_name)

      {
        status: "error",
        message: "Failed to update settings: #{e.message}",
        backtrace: e.backtrace
      }
    end

    private

    # Helper method to safely reopen an index if it's closed
    #
    # @param index_name [String] The name of the index to reopen
    # @return [void]
    def reopen_index(index_name)
      if indices.status(index: index_name).dig("indices", index_name, "state") == "close"
        indices.open(index: index_name)
      end
    rescue => open_error
      # Just log the error without raising
      puts "Warning: Failed to reopen index #{index_name}: #{open_error.message}"
    end
  end
end
