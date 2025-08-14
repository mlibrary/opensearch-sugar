# frozen_string_literal: true

module OpenSearch
  module Sugar
  end
end

require "opensearch"

require_relative "sugar/version"
require_relative "index"

module OpenSearch
  module Sugar
    class Error < StandardError; end

    def self.client(**kwargs)
      OpenSearch::Sugar::Client.new(**kwargs)
    end
  end
end
