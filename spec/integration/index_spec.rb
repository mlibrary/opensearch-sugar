# frozen_string_literal: true

require "integration_helper"

RSpec.describe OpenSearch::Sugar::Index, integration: true do
  describe ".create" do
    it "creates a new index" do
      index_name = "test_create_index_#{Time.now.to_i}"
      @test_indexes << index_name
      index = OpenSearch::Sugar::Index.create(client: @client, name: index_name)
      expect(@client.has_index?(index_name)).to be true
      expect(index.name).to eq(index_name)
    end

    it "raises error when creating duplicate index" do
      index_name = "test_duplicate_#{Time.now.to_i}"
      create_test_index(index_name)
      expect {
        OpenSearch::Sugar::Index.create(client: @client, name: index_name)
      }.to raise_error(ArgumentError, /already exists/)
    end

    it "supports KNN configuration" do
      index_name = "test_knn_#{Time.now.to_i}"
      @test_indexes << index_name
      index = OpenSearch::Sugar::Index.create(client: @client, name: index_name, knn: true)
      settings = index.settings
      expect(settings.dig(index_name, "settings", "index", "knn")).to eq("true")
    end

    it "supports disabling KNN" do
      index_name = "test_no_knn_#{Time.now.to_i}"
      @test_indexes << index_name
      index = OpenSearch::Sugar::Index.create(client: @client, name: index_name, knn: false)
      settings = index.settings
      expect(settings.dig(index_name, "settings", "index", "knn")).to eq("false")
    end
  end

  describe ".open" do
    it "opens an existing index" do
      index_name = "test_open_#{Time.now.to_i}"
      create_test_index(index_name)
      index = OpenSearch::Sugar::Index.open(client: @client, name: index_name)
      expect(index.name).to eq(index_name)
      expect(index).to be_a(OpenSearch::Sugar::Index)
    end

    it "raises error for non-existent index" do
      expect {
        OpenSearch::Sugar::Index.open(client: @client, name: "nonexistent_#{Time.now.to_i}")
      }.to raise_error(ArgumentError, /not found/)
    end
  end

  describe "#delete!" do
    it "deletes the index" do
      index_name = "test_delete_#{Time.now.to_i}"
      index = create_test_index(index_name)
      index.delete!
      expect(@client.has_index?(index_name)).to be false
      @test_indexes.delete(index_name) # Already deleted, don't try again
    end
  end

  describe "#count" do
    it "returns 0 for empty index" do
      index_name = "test_count_empty_#{Time.now.to_i}"
      index = create_test_index(index_name)
      expect(index.count).to eq(0)
    end

    it "returns correct count after indexing documents" do
      index_name = "test_count_docs_#{Time.now.to_i}"
      index = create_test_index(index_name)
      @client.index(index: index_name, id: "1", body: {title: "Test Doc 1"})
      @client.index(index: index_name, id: "2", body: {title: "Test Doc 2"})
      @client.indices.refresh(index: index_name)
      expect(index.count).to eq(2)
    end
  end

  describe "#clear!" do
    it "deletes all documents from index" do
      index_name = "test_clear_#{Time.now.to_i}"
      index = create_test_index(index_name)
      @client.index(index: index_name, id: "1", body: {title: "Doc 1"})
      @client.index(index: index_name, id: "2", body: {title: "Doc 2"})
      @client.index(index: index_name, id: "3", body: {title: "Doc 3"})
      @client.indices.refresh(index: index_name)

      deleted_count = index.clear!
      expect(deleted_count).to eq(3)
      
      @client.indices.refresh(index: index_name)
      expect(index.count).to eq(0)
    end

    it "returns 0 when clearing an already empty index" do
      index_name = "test_clear_empty_#{Time.now.to_i}"
      index = create_test_index(index_name)
      deleted_count = index.clear!
      expect(deleted_count).to eq(0)
    end
  end

  describe "#delete_by_id" do
    it "deletes a document by ID" do
      index_name = "test_delete_by_id_#{Time.now.to_i}"
      index = create_test_index(index_name)
      @client.index(index: index_name, id: "doc1", body: {title: "Document 1"})
      @client.indices.refresh(index: index_name)

      result = index.delete_by_id("doc1")
      expect(result["result"]).to eq("deleted")

      @client.indices.refresh(index: index_name)
      expect(index.count).to eq(0)
    end

    it "raises error for nil ID" do
      index_name = "test_delete_nil_#{Time.now.to_i}"
      index = create_test_index(index_name)
      expect {
        index.delete_by_id(nil)
      }.to raise_error(ArgumentError, /cannot be nil/)
    end

    it "raises error for empty ID" do
      index_name = "test_delete_empty_#{Time.now.to_i}"
      index = create_test_index(index_name)
      expect {
        index.delete_by_id("")
      }.to raise_error(ArgumentError, /cannot be nil or empty/)
    end
  end

  describe "#settings" do
    it "returns index settings" do
      index_name = "test_settings_#{Time.now.to_i}"
      index = create_test_index(index_name)
      settings = index.settings
      expect(settings).to be_a(Hash)
      expect(settings).to have_key(index_name)
    end
  end

  describe "#mappings" do
    it "returns index mappings" do
      index_name = "test_mappings_#{Time.now.to_i}"
      index = create_test_index(index_name)
      mappings = index.mappings
      expect(mappings).to be_a(Hash)
      expect(mappings).to have_key(index_name)
    end
  end

  describe "#update_settings" do
    it "updates index settings successfully" do
      index_name = "test_update_settings_#{Time.now.to_i}"
      index = create_test_index(index_name)

      settings = {
        analysis: {
          analyzer: {
            custom_test_analyzer: {
              type: "standard",
              stopwords: "_english_"
            }
          }
        }
      }

      result = index.update_settings(settings)
      expect(result[:status]).to eq("success")

      updated_settings = index.settings
      expect(updated_settings.dig(index_name, "settings", "index", "analysis", "analyzer", "custom_test_analyzer")).not_to be_nil
    end
  end

  describe "#update_mappings" do
    it "updates index mappings successfully" do
      index_name = "test_update_mappings_#{Time.now.to_i}"
      index = create_test_index(index_name)

      mappings = {
        properties: {
          title: {type: "text"},
          description: {type: "text"},
          created_at: {type: "date"}
        }
      }

      result = index.update_mappings(mappings)
      expect(result[:status]).to eq("success")

      updated_mappings = index.mappings
      expect(updated_mappings.dig(index_name, "mappings", "properties", "title", "type")).to eq("text")
      expect(updated_mappings.dig(index_name, "mappings", "properties", "created_at", "type")).to eq("date")
    end
  end
end

