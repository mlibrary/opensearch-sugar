# frozen_string_literal: true

module OpenSearch
  module Sugar
  end
end

require "opensearch"

require_relative "sugar/version"
require_relative "sugar/index"
require_relative "sugar/client"

module OpenSearch
  # Top-level namespace for the opensearch-sugar gem.
  #
  # Provides a thin, object-oriented wrapper around the {https://github.com/opensearch-project/opensearch-ruby opensearch-ruby}
  # client. The main entry point is {OpenSearch::Sugar.client}, which returns a
  # fully configured {OpenSearch::Sugar::Client}.
  #
  # @see OpenSearch::Sugar::Client
  # @see OpenSearch::Sugar::Index
  # @see OpenSearch::Sugar::Models
  module Sugar
    # Base error class for all opensearch-sugar exceptions.
    #
    # Raised when operations such as settings or mappings updates fail.
    # Rescuing this class catches all gem-specific errors without catching
    # unrelated OpenSearch transport-layer exceptions.
    #
    # @example
    #   begin
    #     client.update_settings(bad_settings, "my_index")
    #   rescue OpenSearch::Sugar::Error => e
    #     puts "Settings update failed: #{e.message}"
    #   end
    class Error < StandardError; end

    # Convenience factory that returns a new {OpenSearch::Sugar::Client}.
    #
    # Accepts the same keyword arguments as {OpenSearch::Sugar::Client#initialize}.
    #
    # @param kwargs [Hash] Keyword arguments forwarded to {OpenSearch::Sugar::Client#initialize}
    # @return [OpenSearch::Sugar::Client]
    # @example
    #   client = OpenSearch::Sugar.client(host: "https://localhost:9200")
    def self.client(**kwargs)
      OpenSearch::Sugar::Client.new(**kwargs)
    end

    # Alias for {.client}. Allows idiomatic +OpenSearch::Sugar.new(...)+ construction.
    #
    # @param kwargs [Hash] Keyword arguments forwarded to {OpenSearch::Sugar::Client#initialize}
    # @return [OpenSearch::Sugar::Client]
    # @example
    #   client = OpenSearch::Sugar.new
    def self.new(**kwargs)
      client(**kwargs)
    end
  end
end
