# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Index, "lifecycle" do
  include_context "opensearch client"

  let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }

  after { client.delete_index!(index_name) rescue nil }

  describe ".open" do
    context "when the index exists" do
      before { client.open_or_create_index(index_name) }

      it "returns an Index with the correct name" do
        index = OpenSearch::Sugar::Index.open(client: client, name: index_name)
        expect(index).to be_a(OpenSearch::Sugar::Index)
        expect(index.name).to eq(index_name)
      end
    end

    context "when the index does not exist" do
      it "raises ArgumentError" do
        expect {
          OpenSearch::Sugar::Index.open(client: client, name: index_name)
        }.to raise_error(ArgumentError, /not found/)
      end
    end
  end

  describe ".create" do
    context "when the index does not exist" do
      it "creates the index and returns an Index" do
        index = OpenSearch::Sugar::Index.create(client: client, name: index_name)
        expect(index).to be_a(OpenSearch::Sugar::Index)
        expect(client.has_index?(index_name)).to be true
      end
    end

    context "when the index already exists" do
      before { client.open_or_create_index(index_name) }

      it "raises ArgumentError" do
        expect {
          OpenSearch::Sugar::Index.create(client: client, name: index_name)
        }.to raise_error(ArgumentError, /already exists/)
      end
    end
  end

  describe "#delete!" do
    before { client.open_or_create_index(index_name) }

    it "deletes the index" do
      index = OpenSearch::Sugar::Index.open(client: client, name: index_name)
      index.delete!
      expect(client.has_index?(index_name)).to be false
    end
  end
end
