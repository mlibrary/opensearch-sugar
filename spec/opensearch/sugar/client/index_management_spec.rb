# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Client, "index management" do
  include_context "opensearch client"

  let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }

  after { client.indices.delete(index: index_name) rescue nil }

  describe "#has_index?" do
    context "when the index does not exist" do
      it "returns false" do
        expect(client.has_index?(index_name)).to be false
      end
    end

    context "when the index exists" do
      before { client.indices.create(index: index_name) }

      it "returns true" do
        expect(client.has_index?(index_name)).to be true
      end
    end
  end

  describe "#index_names" do
    before { client.indices.create(index: index_name) }

    it "includes the created index" do
      expect(client.index_names).to include(index_name)
    end

    it "returns an Array of Strings" do
      expect(client.index_names).to be_an(Array)
      expect(client.index_names).to all(be_a(String))
    end
  end

  describe "#[]" do
    before { client.indices.create(index: index_name) }

    it "returns an OpenSearch::Sugar::Index for an existing index" do
      expect(client[index_name]).to be_a(OpenSearch::Sugar::Index)
    end

    it "returns an Index with the correct name" do
      expect(client[index_name].name).to eq(index_name)
    end

    it "raises ArgumentError for a non-existent index" do
      expect { client["nonexistent_#{SecureRandom.hex(6)}"] }.to raise_error(ArgumentError)
    end
  end

  describe "#open_or_create" do
    context "when the index does not exist" do
      it "creates and returns an Index" do
        index = client.open_or_create(index_name)
        expect(index).to be_a(OpenSearch::Sugar::Index)
        expect(client.has_index?(index_name)).to be true
      end
    end

    context "when the index already exists" do
      before { client.indices.create(index: index_name) }

      it "opens and returns the existing Index" do
        index = client.open_or_create(index_name)
        expect(index).to be_a(OpenSearch::Sugar::Index)
        expect(index.name).to eq(index_name)
      end
    end
  end
end
