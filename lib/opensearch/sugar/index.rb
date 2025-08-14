# frozen_string_literal: true

require_relative "client"

module OpenSearch::Sugar
  class Index
    # @return OpenSearch::Sugar::Client
    attr_accessor :client

    attr_accessor :name

    # @param client [OpenSearch::Sugar::Client]
    def self.open(client:, name:)
      raise ArgumentError, "Index #{name} not found" unless exists?(index: name)
      new(client: client, name: name)
    end

    def self.create(client:, name:)
      raise ArgumentError.new("Index #{name} already exists") if client.indices.exists?(index: name)
      new(client: client, name: name)
    end

    def self.exists?(name)
      client.indices.exists?(index: name)
    end

    def upload_settings(settings)
      client.upload_settings(settings, name)
    end

    private

    def initialize(client:, name:)
      @client = client
      @name = name
      client.indices.create(index: name, body: default_index_body)
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
