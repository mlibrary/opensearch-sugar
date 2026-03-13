# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Client, type: :integration do
  describe "initialization and connection" do
    it "creates a client with URL only" do
      client = described_class.new(url: OPENSEARCH_URL)
      expect(client).to be_a(described_class)
    end

    it "creates a client with authentication" do
      client = described_class.new(
        url: OPENSEARCH_URL,
        user: OPENSEARCH_USER,
        password: OPENSEARCH_PASSWORD
      )
      expect(client).to be_a(described_class)
    end

    it "pings OpenSearch successfully" do
      expect(test_client.ping).to be true
    end

    it "retrieves cluster info" do
      info = test_client.info
      expect(info).to be_a(Hash)
      expect(info).to have_key("version")
      expect(info["version"]).to have_key("number")
    end

    it "handles connection errors gracefully" do
      bad_client = described_class.new(url: "http://localhost:9999")
      expect { bad_client.info }.to raise_error(StandardError)
    end
  end

  describe "cluster operations" do
    it "retrieves cluster health", :retry_on_cluster do
      health = test_client.cluster.health
      expect(health).to be_a(Hash)
      expect(health).to have_key("status")
      expect(health["status"]).to match(/green|yellow|red/)
    end

    it "retrieves cluster stats", :retry_on_cluster do
      stats = test_client.cluster.stats
      expect(stats).to be_a(Hash)
      expect(stats).to have_key("nodes")
      expect(stats).to have_key("indices")
    end

    it "lists nodes" do
      nodes = test_client.cat.nodes(format: "json")
      expect(nodes).to be_an(Array)
      expect(nodes).not_to be_empty
    end
  end

  describe "index operations" do
    it "creates an Index instance" do
      index = test_client[test_index_name]
      expect(index).to be_a(OpenSearch::Sugar::Index)
    end

    it "lists indices" do
      index_name = test_index_name
      test_client[index_name].create
      wait_for_index(index_name)

      indices = test_client.cat.indices(format: "json")
      expect(indices).to be_an(Array)
      expect(indices.map { |idx| idx["index"] }).to include(index_name)
    end

    it "creates multiple indices" do
      index1_name = test_index_name("first")
      index2_name = test_index_name("second")

      test_client.open_or_create(index1_name)
      test_client.open_or_create(index2_name)

      wait_for_index(index1_name)
      wait_for_index(index2_name)

      indices = test_client.cat.indices(format: "json")
      index_names = indices.map { |idx| idx["index"] }

      expect(index_names).to include(index1_name)
      expect(index_names).to include(index2_name)
    end
  end

  describe "bulk operations" do
    let(:index) { create_test_index }

    it "performs bulk indexing" do
      docs = generate_documents(10)

      bulk_body = docs.flat_map do |doc|
        [
          {index: {_index: index.name, _id: doc[:id]}},
          doc
        ]
      end

      response = test_client.bulk(body: bulk_body)
      expect(response["errors"]).to be false

      wait_for_documents(index, expected_count: 10)
      expect(index.count).to eq(10)
    end

    it "handles bulk errors" do
      bulk_body = [
        {index: {_index: index.name, _id: "1"}},
        {invalid_field: "x" * 1_000_000}
      ]

      response = test_client.bulk(body: bulk_body)
      expect(response).to be_a(Hash)
      expect(response).to have_key("items")
    end
  end

  describe "search operations" do
    let(:index) { create_test_index(mappings: book_mapping) }

    before do
      docs = generate_documents(20) do |doc, i|
        doc.merge(
          author: (i < 10) ? "Author A" : "Author B",
          genre: (i < 5) ? "Fiction" : "Non-Fiction",
          rating: (i % 5) + 1.0
        )
      end

      docs.each do |doc|
        index.index(id: doc[:id], body: doc)
      end

      wait_for_documents(index, expected_count: 20)
    end

    it "searches across all indices", :retry_on_search do
      results = test_client.search(body: {query: {match: {author: "Author A"}}})
      expect(results).to be_a(Hash)
      expect(results["hits"]["total"]["value"]).to be >= 10
    end

    it "searches with size limit", :retry_on_search do
      results = test_client.search(
        index: index.name,
        body: {query: {match_all: {}}, size: 5}
      )
      expect(results["hits"]["hits"].size).to eq(5)
    end

    it "searches with aggregations", :retry_on_search do
      results = test_client.search(
        index: index.name,
        body: {
          query: {match_all: {}},
          aggs: {
            by_genre: {
              terms: {field: "genre"}
            }
          }
        }
      )

      expect(results["aggregations"]).to have_key("by_genre")
      expect(results["aggregations"]["by_genre"]["buckets"]).to be_an(Array)
    end
  end

  describe "cat API operations" do
    it "lists indices with cat API" do
      index_name = test_index_name
      test_client[index_name].create
      wait_for_index(index_name)

      indices = test_client.cat.indices(format: "json")
      expect(indices).to be_an(Array)
      expect(indices.first).to have_key("index")
      expect(indices.first).to have_key("health")
    end

    it "shows allocation with cat API" do
      allocation = test_client.cat.allocation(format: "json")
      expect(allocation).to be_an(Array)
    end

    it "shows shards with cat API" do
      shards = test_client.cat.shards(format: "json")
      expect(shards).to be_an(Array)
    end
  end

  describe "template operations" do
    let(:template_name) { "#{TEST_INDEX_PREFIX}_template_#{SecureRandom.hex(4)}" }

    after do
      test_client.indices.delete_index_template(name: template_name)
    rescue
      # Template may not exist
    end

    it "creates an index template" do
      response = test_client.indices.put_index_template(
        name: template_name,
        body: {
          index_patterns: ["#{TEST_INDEX_PREFIX}_*"],
          template: {
            settings: standard_settings,
            mappings: book_mapping
          }
        }
      )

      expect(response).to be_a(Hash)
      expect(response["acknowledged"]).to be true
    end

    it "retrieves an index template" do
      test_client.indices.put_index_template(
        name: template_name,
        body: {
          index_patterns: ["#{TEST_INDEX_PREFIX}_*"],
          template: {
            settings: standard_settings
          }
        }
      )

      response = test_client.indices.get_index_template(name: template_name)
      expect(response).to be_a(Hash)
      expect(response["index_templates"]).to be_an(Array)
    end
  end

  describe "snapshot operations", :retry_on_cluster do
    it "lists snapshot repositories" do
      response = test_client.snapshot.get_repository(repository: "_all")
      expect(response).to be_a(Hash)
    end
  end

  describe "error handling" do
    it "raises error for non-existent index operations" do
      expect {
        test_client.indices.get(index: "non_existent_index_#{SecureRandom.hex(8)}")
      }.to raise_error(StandardError)
    end

    it "handles malformed queries" do
      index = create_test_index
      expect {
        test_client.search(
          index: index.name,
          body: {query: {invalid_query_type: {}}}
        )
      }.to raise_error(StandardError)
    end
  end
end
