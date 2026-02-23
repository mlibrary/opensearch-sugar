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
  module Sugar
    class Error < StandardError; end

    def self.client(**kwargs)
      OpenSearch::Sugar::Client.new(**kwargs)
    end

    def self.new(**kwargs)
      client(**kwargs)
    end
  end
end
