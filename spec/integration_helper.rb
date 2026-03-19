# frozen_string_literal: true

require_relative "spec_helper"
require "dotenv/load"

# Load test environment configuration
Dotenv.load("env.test")

RSpec.configure do |config|
  # Only run integration tests when explicitly requested
  config.filter_run_excluding integration: true unless ENV["RUN_INTEGRATION_TESTS"]

  # Shared client for all tests
  config.before(:suite) do
    # Skip if not running integration tests
    next unless ENV["RUN_INTEGRATION_TESTS"]

    # Verify OpenSearch is available
    @suite_client = OpenSearch::Sugar.client(
      host: ENV["OPENSEARCH_HOST"],
      user: ENV["OPENSEARCH_USER"],
      password: ENV["OPENSEARCH_PASSWORD"]
    )

    # Verify connection
    info = @suite_client.info
    puts "\nConnected to OpenSearch #{info["version"]["number"]} at #{ENV["OPENSEARCH_HOST"]}"
    puts "Cluster: #{info["cluster_name"]}"
  rescue => e
    puts "\nFailed to connect to OpenSearch: #{e.message}"
    puts "Make sure OpenSearch is running and OPENSEARCH_HOST is set correctly"
    raise
  end

  config.after(:suite) do
    next unless ENV["RUN_INTEGRATION_TESTS"]

    # Clean up any test indexes that weren't cleaned properly
    if @suite_client
      @suite_client.index_names.each do |index_name|
        if index_name.start_with?("test_")
          puts "Cleaning up leftover test index: #{index_name}"
          @suite_client.indices.delete(index: index_name)
        end
      end
    end
  end

  # Make client available to all integration tests
  config.before(:each, integration: true) do
    @client = OpenSearch::Sugar.client(
      host: ENV["OPENSEARCH_HOST"],
      user: ENV["OPENSEARCH_USER"],
      password: ENV["OPENSEARCH_PASSWORD"]
    )
    @test_indexes = []
  end

  # Clean up after each test
  config.after(:each, integration: true) do
    # Delete all test indexes created during this test
    @test_indexes&.each do |index_name|
      if @client.has_index?(index_name)
        @client.indices.delete(index: index_name)
      end
    rescue => e
      puts "Warning: Failed to delete test index #{index_name}: #{e.message}"
    end
  end
end

# Helper to track test indexes for cleanup
def create_test_index(name, **options)
  @test_indexes ||= []
  @test_indexes << name
  index = @client.open_or_create(name, **options)
  index
end


