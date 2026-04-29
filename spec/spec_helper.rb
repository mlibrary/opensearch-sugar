# frozen_string_literal: true

require "opensearch/sugar"
require "dotenv"

# TODO: Add OpenSearch startup readiness check so specs don't fail when the cluster
# is still initializing after `docker compose up -d`. Recommended approach:
#   1. Add a healthcheck to compose_opensearch.yml and use `docker compose up -d --wait`
#   2. Add a before(:suite) poll in this file as a belt-and-suspenders fallback:
#        client = OpenSearch::Sugar::Client.new
#        deadline = Time.now + 60
#        until client.ping rescue false
#          raise "OpenSearch did not become available within 60s" if Time.now > deadline
#          sleep 2
#        end

Dotenv.load(File.join(__dir__, "env.testing"))

require_relative "support/opensearch_client"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # ML model tests are slow and require a running ML plugin. Exclude by default.
  # Run with: bundle exec rspec --tag models
  config.filter_run_excluding :models
end
