# frozen_string_literal: true

require "faker"
require "securerandom"

# Configuration constants for integration tests
# These are loaded from spec/env.spec via Dotenv in spec_helper.rb
OPENSEARCH_URL = ENV.fetch("OPENSEARCH_URL")
OPENSEARCH_USER = ENV.fetch("OPENSEARCH_USER")
OPENSEARCH_PASSWORD = ENV.fetch("OPENSEARCH_PASSWORD")
TEST_INDEX_PREFIX = "test_opensearch_sugar"

module IntegrationHelper
  # Generate a unique test index name
  def test_index_name(base_name = "index")
    @test_indices ||= []
    index_name = "#{TEST_INDEX_PREFIX}_#{base_name}_#{SecureRandom.hex(8)}"
    @test_indices << index_name
    index_name
  end

  # Create a test client
  def test_client
    @test_client ||= OpenSearch::Sugar::Client.new(
      url: OPENSEARCH_URL,
      user: OPENSEARCH_USER,
      password: OPENSEARCH_PASSWORD,
      log: false
    )
  end

  # Create a test index with optional settings and mappings
  def create_test_index(name = nil, settings: nil, mappings: nil)
    name ||= test_index_name
    index = test_client[name]

    body = {}
    body[:settings] = settings if settings
    body[:mappings] = mappings if mappings

    index.create(body: body.empty? ? nil : body)
    index
  end

  # Generate sample documents using Faker
  def generate_document(overrides = {})
    {
      id: SecureRandom.uuid,
      title: Faker::Book.title,
      author: Faker::Book.author,
      genre: Faker::Book.genre,
      publisher: Faker::Book.publisher,
      isbn: Faker::Code.isbn,
      price: Faker::Commerce.price(range: 10.0..100.0),
      publish_date: Faker::Date.between(from: "1950-01-01", to: Date.today).iso8601,
      description: Faker::Lorem.paragraph(sentence_count: 3),
      rating: rand(1.0..5.0).round(1),
      pages: rand(100..1000),
      available: [true, false].sample,
      tags: Array.new(rand(1..5)) { Faker::Book.genre },
      created_at: Time.now.utc.iso8601
    }.merge(overrides)
  end

  # Generate multiple documents
  def generate_documents(count, &block)
    Array.new(count) do |i|
      doc = generate_document
      block ? block.call(doc, i) : doc
    end
  end

  # Wait for index to be ready (yellow or green status)
  def wait_for_index(index_name, timeout: 30)
    start_time = Time.now
    loop do
      response = test_client.cluster.health(
        index: index_name,
        wait_for_status: "yellow",
        timeout: "5s"
      )
      return true if %w[yellow green].include?(response["status"])
    rescue => e
      raise "Index #{index_name} not ready after #{timeout}s: #{e.message}" if Time.now - start_time > timeout
      sleep 0.5
    end
  end

  # Wait for documents to be searchable (refresh and allow propagation)
  def wait_for_documents(index, expected_count: nil, timeout: 10)
    index.refresh

    if expected_count
      start_time = Time.now
      loop do
        count = index.count
        return true if count >= expected_count
        raise "Expected #{expected_count} documents, got #{count} after #{timeout}s" if Time.now - start_time > timeout
        sleep 0.1
      end
    else
      sleep 0.1 # Brief pause to ensure documents are searchable
    end
  end

  # Cleanup: Delete all test indices created during the test
  def cleanup_test_indices
    return unless @test_indices

    @test_indices.each do |index_name|
      test_client[index_name].delete if test_client[index_name].exists?
    rescue => e
      warn "Failed to cleanup index #{index_name}: #{e.message}"
    end

    @test_indices.clear
  end

  # Verify OpenSearch is available
  def opensearch_available?
    test_client.ping
  rescue
    false
  end

  # Get cluster health
  def cluster_health
    test_client.cluster.health
  end

  # Create a sample mapping for book documents
  def book_mapping
    {
      properties: {
        id: {type: "keyword"},
        title: {type: "text", fields: {keyword: {type: "keyword"}}},
        author: {type: "text", fields: {keyword: {type: "keyword"}}},
        genre: {type: "keyword"},
        publisher: {type: "keyword"},
        isbn: {type: "keyword"},
        price: {type: "float"},
        publish_date: {type: "date"},
        description: {type: "text"},
        rating: {type: "float"},
        pages: {type: "integer"},
        available: {type: "boolean"},
        tags: {type: "keyword"},
        created_at: {type: "date"}
      }
    }
  end

  # Create a sample settings configuration
  def standard_settings(shards: 1, replicas: 0)
    {
      number_of_shards: shards,
      number_of_replicas: replicas,
      refresh_interval: "1s"
    }
  end

  # Retry helper for flaky operations
  def retry_on_failure(max_attempts: 3, delay: 0.5)
    attempts = 0
    begin
      attempts += 1
      yield
    rescue => e
      if attempts < max_attempts
        sleep delay
        retry
      else
        raise e
      end
    end
  end
end

# Configure RSpec to use the helper
RSpec.configure do |config|
  config.include IntegrationHelper, type: :integration

  # Cleanup after each integration test
  config.after(:each, type: :integration) do
    cleanup_test_indices
  end

  # Global cleanup after all tests (only runs if integration tests were executed)
  config.after(:suite) do
    next unless ENV["RUN_INTEGRATION_TESTS"]

    helper = Object.new.extend(IntegrationHelper)

    # Only cleanup if OpenSearch is available
    next unless helper.opensearch_available?

    client = helper.test_client

    # Delete any remaining test indices
    begin
      response = client.cat.indices(format: "json")
      test_indices = response.select { |idx| idx["index"].start_with?(TEST_INDEX_PREFIX) }

      test_indices.each do |idx|
        client.index(idx["index"]).delete
      rescue => e
        warn "Failed to cleanup index #{idx["index"]}: #{e.message}"
      end
    rescue
      # Silently ignore if we can't connect
    end
  end
end
