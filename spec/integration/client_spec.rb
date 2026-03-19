# frozen_string_literal: true

require "integration_helper"

RSpec.describe OpenSearch::Sugar::Client, integration: true do
  describe "#initialize" do
    it "connects successfully with environment credentials" do
      expect(@client.info).to include("version")
    end

    it "connects to the expected cluster" do
      info = @client.info
      expect(info["cluster_name"]).to eq("opensearch")
    end

    it "can retrieve cluster health" do
      health = @client.cluster.health
      expect(%w[green yellow red]).to include(health["status"])
    end
  end

  describe "#has_index?" do
    it "returns false for non-existent index" do
      expect(@client.has_index?("nonexistent_index_#{Time.now.to_i}")).to be false
    end

    it "returns true after creating an index" do
      index = create_test_index("test_has_index_#{Time.now.to_i}")
      expect(@client.has_index?(index.name)).to be true
    end
  end

  describe "#index_names" do
    it "returns array of index names" do
      expect(@client.index_names).to be_an(Array)
    end

    it "includes newly created test index" do
      index_name = "test_index_names_#{Time.now.to_i}"
      create_test_index(index_name)
      expect(@client.index_names).to include(index_name)
    end
  end

  describe "#[]" do
    it "opens an existing index" do
      index_name = "test_bracket_access_#{Time.now.to_i}"
      create_test_index(index_name)
      index = @client[index_name]
      expect(index).to be_a(OpenSearch::Sugar::Index)
      expect(index.name).to eq(index_name)
    end

    it "raises error for non-existent index" do
      expect {
        @client["nonexistent_#{Time.now.to_i}"]
      }.to raise_error(ArgumentError, /not found/)
    end
  end

  describe "#open_or_create" do
    it "creates a new index if it doesn't exist" do
      index_name = "test_open_or_create_new_#{Time.now.to_i}"
      @test_indexes << index_name
      index = @client.open_or_create(index_name)
      expect(@client.has_index?(index_name)).to be true
      expect(index.name).to eq(index_name)
    end

    it "opens an existing index if it exists" do
      index_name = "test_open_or_create_existing_#{Time.now.to_i}"
      create_test_index(index_name)
      index = @client.open_or_create(index_name)
      expect(index.name).to eq(index_name)
    end
  end
end

