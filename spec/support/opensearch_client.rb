# frozen_string_literal: true

# Shared context for integration specs that need a live OpenSearch::Sugar::Client.
#
# Provides:
#   let(:client) — an OpenSearch::Sugar::Client connected to the test cluster
#
# Connection settings are loaded from spec/env.testing via dotenv in spec_helper.rb.
#
# Usage:
#   RSpec.describe "something" do
#     include_context "opensearch client"
#     ...
#   end

RSpec.shared_context "opensearch client" do
  let(:client) { OpenSearch::Sugar::Client.new(log: ENV["OPENSEARCH_LOG"] == "true") }
end
