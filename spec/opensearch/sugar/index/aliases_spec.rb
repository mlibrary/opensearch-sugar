# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Index, "aliases" do
  include_context "opensearch client"

  let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }
  let(:alias_name) { "sugar_alias_#{SecureRandom.hex(6)}" }
  let(:index) { OpenSearch::Sugar::Index.create(client: client, name: index_name) }

  before { index }

  after { client.indices.delete(index: index_name) rescue nil }

  describe "#aliases" do
    it "returns an empty array for a new index with no aliases" do
      expect(index.aliases).to eq([])
    end

    it "returns an Array" do
      expect(index.aliases).to be_an(Array)
    end
  end

  describe "#create_alias" do
    it "adds the alias to the index" do
      index.create_alias(alias_name)
      expect(index.aliases).to include(alias_name)
    end

    it "returns the updated list of aliases" do
      result = index.create_alias(alias_name)
      expect(result).to be_an(Array)
      expect(result).to include(alias_name)
    end

    it "allows multiple aliases on the same index" do
      second_alias = "sugar_alias_#{SecureRandom.hex(6)}"
      index.create_alias(alias_name)
      index.create_alias(second_alias)
      expect(index.aliases).to include(alias_name, second_alias)
    end
  end
end
