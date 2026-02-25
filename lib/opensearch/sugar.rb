# frozen_string_literal: true

module OpenSearch
  # OpenSearch::Sugar - A Ruby client library that adds syntactic sugar to the OpenSearch Ruby client
  #
  # This module provides a more convenient and Ruby-idiomatic interface for working with OpenSearch,
  # including simplified index management, ML model operations, and document handling.
  #
  # @see https://docs.opensearch.org/latest/
  module Sugar
  end
end

require "opensearch"

require_relative "sugar/version"
require_relative "sugar/index"
require_relative "sugar/client"

module OpenSearch
  module Sugar
    # Base error class for OpenSearch::Sugar exceptions
    class Error < StandardError; end

    # Creates a new OpenSearch::Sugar::Client instance
    #
    # This is the primary entry point for creating a client connection to OpenSearch.
    #
    # @param kwargs [Hash] Keyword arguments to pass to the Client constructor
    # @option kwargs [String] :host The OpenSearch host to connect to
    # @option kwargs [String] :user The username for authentication
    # @option kwargs [String] :password The password for authentication
    # @return [OpenSearch::Sugar::Client] A new client instance
    # @see OpenSearch::Sugar::Client#initialize
    # @example Create a client with default settings
    #   client = OpenSearch::Sugar.client
    # @example Create a client with custom host
    #   client = OpenSearch::Sugar.client(host: "https://my-cluster:9200")
    def self.client(**kwargs)
      OpenSearch::Sugar::Client.new(**kwargs)
    end

    # Creates a new OpenSearch::Sugar::Client instance
    #
    # This is an alias for {.client} to provide a more intuitive API.
    #
    # @param kwargs [Hash] Keyword arguments to pass to the Client constructor
    # @return [OpenSearch::Sugar::Client] A new client instance
    # @see .client
    # @example Create a client
    #   client = OpenSearch::Sugar.new(host: "https://localhost:9200")
    def self.new(**kwargs)
      client(**kwargs)
    end
  end
end
