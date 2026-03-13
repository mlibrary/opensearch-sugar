# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Index, type: :integration do
  let(:index_name) { test_index_name }
  let(:index) { test_client[index_name] }

  describe "index lifecycle" do
    it "creates a new index" do
      expect(index.exists?).to be false

      index.create
      wait_for_index(index_name)

      expect(index.exists?).to be true
    end

    it "creates an index with settings" do
      index.create(body: {settings: standard_settings(shards: 2, replicas: 1)})
      wait_for_index(index_name)

      settings = index.settings
      expect(settings[index_name]["settings"]["index"]["number_of_shards"]).to eq("2")
    end

    it "creates an index with mappings" do
      index.create(body: {mappings: book_mapping})
      wait_for_index(index_name)

      mappings = index.mappings
      expect(mappings[index_name]["mappings"]["properties"]).to have_key("title")
    end

    it "creates an index with both settings and mappings" do
      index.create(
        body: {
          settings: standard_settings,
          mappings: book_mapping
        }
      )
      wait_for_index(index_name)

      expect(index.exists?).to be true
      mappings = index.mappings
      expect(mappings[index_name]["mappings"]["properties"]).to have_key("author")
    end

    it "deletes an index" do
      index.create
      wait_for_index(index_name)
      expect(index.exists?).to be true

      index.delete
      expect(index.exists?).to be false
    end

    it "handles creating an already existing index" do
      index.create
      wait_for_index(index_name)

      expect { index.create }.to raise_error(StandardError)
    end
  end

  describe "document operations" do
    before do
      create_test_index(index_name, mappings: book_mapping)
    end

    it "indexes a document with auto-generated ID" do
      doc = generate_document
      response = index.index(body: doc)

      expect(response).to have_key("_id")
      expect(response["result"]).to eq("created")
    end

    it "indexes a document with specified ID" do
      doc = generate_document
      doc_id = doc[:id]

      response = index.index(id: doc_id, body: doc)

      expect(response["_id"]).to eq(doc_id)
      expect(response["result"]).to eq("created")
    end

    it "updates an existing document" do
      doc = generate_document
      doc_id = doc[:id]

      index.index(id: doc_id, body: doc)
      wait_for_documents(index)

      updated_doc = doc.merge(title: "Updated Title")
      response = index.index(id: doc_id, body: updated_doc)

      expect(response["result"]).to eq("updated")
    end

    it "retrieves a document by ID" do
      doc = generate_document
      doc_id = doc[:id]

      index.index(id: doc_id, body: doc)
      wait_for_documents(index)

      retrieved = index.get(id: doc_id)
      expect(retrieved["_id"]).to eq(doc_id)
      expect(retrieved["_source"]["title"]).to eq(doc[:title])
    end

    it "deletes a document by ID" do
      doc = generate_document
      doc_id = doc[:id]

      index.index(id: doc_id, body: doc)
      wait_for_documents(index)

      response = index.delete(id: doc_id)
      expect(response["result"]).to eq("deleted")

      expect { index.get(id: doc_id) }.to raise_error(StandardError)
    end

    it "updates a document using update API" do
      doc = generate_document
      doc_id = doc[:id]

      index.index(id: doc_id, body: doc)
      wait_for_documents(index)

      response = index.update(
        id: doc_id,
        body: {doc: {title: "Updated via Update API"}}
      )

      expect(response["result"]).to eq("updated")

      updated = index.get(id: doc_id)
      expect(updated["_source"]["title"]).to eq("Updated via Update API")
    end
  end

  describe "bulk operations" do
    before do
      create_test_index(index_name, mappings: book_mapping)
    end

    it "performs bulk indexing" do
      docs = generate_documents(50)

      bulk_body = docs.flat_map do |doc|
        [
          {index: {_id: doc[:id]}},
          doc
        ]
      end

      response = index.bulk(body: bulk_body)
      expect(response["errors"]).to be false

      wait_for_documents(index, expected_count: 50)
      expect(index.count).to eq(50)
    end

    it "performs bulk operations with mixed actions" do
      docs = generate_documents(5)
      docs.each { |doc| index.index(id: doc[:id], body: doc) }
      wait_for_documents(index, expected_count: 5)

      bulk_body = [
        {index: {_id: "new_doc_1"}},
        generate_document(id: "new_doc_1"),
        {update: {_id: docs[0][:id]}},
        {doc: {title: "Updated Title"}},
        {delete: {_id: docs[1][:id]}}
      ]

      response = index.bulk(body: bulk_body)
      expect(response["errors"]).to be false

      wait_for_documents(index)
      expect(index.count).to eq(5)
    end
  end

  describe "search operations" do
    before do
      create_test_index(index_name, mappings: book_mapping)

      docs = generate_documents(30) do |doc, i|
        doc.merge(
          author: ["Alice Author", "Bob Writer", "Charlie Novelist"][i % 3],
          genre: ["Fiction", "Non-Fiction", "Mystery", "Romance", "Sci-Fi"][i % 5],
          rating: (i % 5) + 1.0,
          price: 10.0 + (i * 2.5),
          pages: 100 + (i * 10)
        )
      end

      docs.each { |doc| index.index(id: doc[:id], body: doc) }
      wait_for_documents(index, expected_count: 30)
    end

    it "searches with match_all query", :retry_on_search do
      results = index.search(body: {query: {match_all: {}}})
      expect(results["hits"]["total"]["value"]).to eq(30)
    end

    it "searches with term query", :retry_on_search do
      results = index.search(
        body: {query: {term: {"author.keyword": "Alice Author"}}}
      )
      expect(results["hits"]["total"]["value"]).to eq(10)
    end

    it "searches with match query", :retry_on_search do
      results = index.search(
        body: {query: {match: {author: "Bob"}}}
      )
      expect(results["hits"]["total"]["value"]).to be >= 10
    end

    it "searches with range query", :retry_on_search do
      results = index.search(
        body: {
          query: {
            range: {
              price: {gte: 30, lte: 60}
            }
          }
        }
      )
      expect(results["hits"]["total"]["value"]).to be > 0
    end

    it "searches with bool query", :retry_on_search do
      results = index.search(
        body: {
          query: {
            bool: {
              must: [
                {term: {genre: "Fiction"}}
              ],
              filter: [
                {range: {rating: {gte: 3}}}
              ]
            }
          }
        }
      )
      expect(results["hits"]["total"]["value"]).to be > 0
    end

    it "searches with pagination", :retry_on_search do
      page1 = index.search(body: {query: {match_all: {}}, size: 10, from: 0})
      page2 = index.search(body: {query: {match_all: {}}, size: 10, from: 10})

      expect(page1["hits"]["hits"].size).to eq(10)
      expect(page2["hits"]["hits"].size).to eq(10)

      page1_ids = page1["hits"]["hits"].map { |hit| hit["_id"] }
      page2_ids = page2["hits"]["hits"].map { |hit| hit["_id"] }

      expect(page1_ids & page2_ids).to be_empty
    end

    it "searches with sorting", :retry_on_search do
      results = index.search(
        body: {
          query: {match_all: {}},
          sort: [{price: {order: "asc"}}],
          size: 5
        }
      )

      prices = results["hits"]["hits"].map { |hit| hit["_source"]["price"] }
      expect(prices).to eq(prices.sort)
    end

    it "searches with source filtering", :retry_on_search do
      results = index.search(
        body: {
          query: {match_all: {}},
          _source: ["title", "author"],
          size: 1
        }
      )

      source = results["hits"]["hits"].first["_source"]
      expect(source.keys).to contain_exactly("title", "author")
    end
  end

  describe "aggregations" do
    before do
      create_test_index(index_name, mappings: book_mapping)

      docs = generate_documents(40) do |doc, i|
        doc.merge(
          genre: ["Fiction", "Non-Fiction", "Mystery"][i % 3],
          rating: [1.0, 2.0, 3.0, 4.0, 5.0][i % 5],
          price: 10.0 + (i * 2.0),
          available: i.even?
        )
      end

      docs.each { |doc| index.index(id: doc[:id], body: doc) }
      wait_for_documents(index, expected_count: 40)
    end

    it "performs terms aggregation", :retry_on_search do
      results = index.search(
        body: {
          size: 0,
          aggs: {
            genres: {
              terms: {field: "genre"}
            }
          }
        }
      )

      buckets = results["aggregations"]["genres"]["buckets"]
      expect(buckets).to be_an(Array)
      expect(buckets.size).to be >= 3
    end

    it "performs stats aggregation", :retry_on_search do
      results = index.search(
        body: {
          size: 0,
          aggs: {
            price_stats: {
              stats: {field: "price"}
            }
          }
        }
      )

      stats = results["aggregations"]["price_stats"]
      expect(stats).to have_key("count")
      expect(stats).to have_key("min")
      expect(stats).to have_key("max")
      expect(stats).to have_key("avg")
    end

    it "performs range aggregation", :retry_on_search do
      results = index.search(
        body: {
          size: 0,
          aggs: {
            price_ranges: {
              range: {
                field: "price",
                ranges: [
                  {to: 30},
                  {from: 30, to: 60},
                  {from: 60}
                ]
              }
            }
          }
        }
      )

      buckets = results["aggregations"]["price_ranges"]["buckets"]
      expect(buckets.size).to eq(3)
    end

    it "performs nested aggregations", :retry_on_search do
      results = index.search(
        body: {
          size: 0,
          aggs: {
            genres: {
              terms: {field: "genre"},
              aggs: {
                avg_rating: {
                  avg: {field: "rating"}
                }
              }
            }
          }
        }
      )

      buckets = results["aggregations"]["genres"]["buckets"]
      expect(buckets.first).to have_key("avg_rating")
    end
  end

  describe "index management" do
    before do
      create_test_index(index_name)
    end

    it "refreshes the index" do
      doc = generate_document
      index.index(id: doc[:id], body: doc)

      response = index.refresh
      expect(response).to have_key("_shards")
    end

    it "flushes the index" do
      response = index.flush
      expect(response).to have_key("_shards")
    end

    it "retrieves index stats" do
      stats = index.stats
      expect(stats).to have_key("_all")
      expect(stats["indices"]).to have_key(index_name)
    end

    it "retrieves index settings" do
      settings = index.settings
      expect(settings).to have_key(index_name)
      expect(settings[index_name]).to have_key("settings")
    end

    it "retrieves index mappings" do
      index.put_mapping(body: book_mapping)

      mappings = index.mappings
      expect(mappings).to have_key(index_name)
      expect(mappings[index_name]).to have_key("mappings")
    end

    it "updates index settings" do
      index.update_settings(
        body: {
          index: {
            refresh_interval: "5s"
          }
        }
      )

      settings = index.settings
      expect(settings[index_name]["settings"]["index"]["refresh_interval"]).to eq("5s")
    end

    it "closes and opens index" do
      index.close

      expect { index.search(body: {query: {match_all: {}}}) }.to raise_error(StandardError)

      index.open
      wait_for_index(index_name)

      results = index.search(body: {query: {match_all: {}}})
      expect(results).to have_key("hits")
    end
  end

  describe "count operations" do
    before do
      create_test_index(index_name, mappings: book_mapping)

      docs = generate_documents(25) do |doc, i|
        doc.merge(genre: (i < 10) ? "Fiction" : "Non-Fiction")
      end

      docs.each { |doc| index.index(id: doc[:id], body: doc) }
      wait_for_documents(index, expected_count: 25)
    end

    it "counts all documents", :retry_on_search do
      expect(index.count).to eq(25)
    end

    it "counts with query", :retry_on_search do
      count = index.count(body: {query: {term: {genre: "Fiction"}}})
      expect(count).to eq(10)
    end
  end

  describe "scroll API" do
    before do
      create_test_index(index_name, mappings: book_mapping)

      docs = generate_documents(100)
      docs.each { |doc| index.index(id: doc[:id], body: doc) }
      wait_for_documents(index, expected_count: 100)
    end

    it "scrolls through all documents", :retry_on_search do
      response = index.search(
        body: {query: {match_all: {}}, size: 10},
        scroll: "1m"
      )

      scroll_id = response["_scroll_id"]
      all_hits = response["hits"]["hits"]

      while response["hits"]["hits"].any?
        response = test_client.scroll(scroll_id: scroll_id, scroll: "1m")
        all_hits.concat(response["hits"]["hits"])
        break if response["hits"]["hits"].empty?
      end

      test_client.clear_scroll(scroll_id: scroll_id)

      expect(all_hits.size).to eq(100)
    end
  end

  describe "multi-get operations" do
    before do
      create_test_index(index_name, mappings: book_mapping)
    end

    it "retrieves multiple documents by IDs" do
      docs = generate_documents(5)
      docs.each { |doc| index.index(id: doc[:id], body: doc) }
      wait_for_documents(index, expected_count: 5)

      doc_ids = docs.map { |doc| doc[:id] }

      response = index.mget(body: {ids: doc_ids})
      expect(response["docs"].size).to eq(5)
      expect(response["docs"].all? { |doc| doc["found"] }).to be true
    end
  end

  describe "error handling" do
    it "handles get on non-existent document" do
      create_test_index(index_name)

      expect {
        index.get(id: "non_existent_id")
      }.to raise_error(StandardError)
    end

    it "handles delete on non-existent document" do
      create_test_index(index_name)

      expect {
        index.delete(id: "non_existent_id")
      }.to raise_error(StandardError)
    end

    it "handles operations on non-existent index" do
      non_existent = test_client["non_existent_index_#{SecureRandom.hex(8)}"]

      expect {
        non_existent.search(body: {query: {match_all: {}}})
      }.to raise_error(StandardError)
    end
  end
end
