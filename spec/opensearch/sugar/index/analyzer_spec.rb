# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Index, "analyzers" do
  include_context "opensearch client"

  let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }
  let(:analyzer_settings) do
    {
      settings: {
        analysis: {
          analyzer: {
            test_lower: {
              type: "custom",
              tokenizer: "standard",
              filter: ["lowercase"]
            }
          }
        }
      }
    }
  end
  let(:index) do
    idx = OpenSearch::Sugar::Index.create(client: client, name: index_name)
    idx.update_settings(analyzer_settings)
    idx
  end

  before { index }

  after {
    begin
      client.delete_index!(index_name)
    rescue
      nil
    end
  }

  describe "#all_available_analyzers / #analyzers" do
    it "includes the custom analyzer defined in the index settings" do
      expect(index.all_available_analyzers).to include("test_lower")
    end

    it "returns an Array of Strings" do
      expect(index.all_available_analyzers).to be_an(Array)
      expect(index.all_available_analyzers).to all(be_a(String))
    end

    it "#analyzers is an alias for #all_available_analyzers" do
      expect(index.analyzers).to eq(index.all_available_analyzers)
    end
  end

  describe "#analyze_text" do
    it "returns the tokens produced by the analyzer" do
      tokens = index.analyze_text(analyzer: "test_lower", text: "Hello World")
      expect(tokens).to include("hello", "world")
    end

    it "lowercases tokens with the test_lower analyzer" do
      tokens = index.analyze_text(analyzer: "test_lower", text: "ALLCAPS")
      expect(tokens).to include("allcaps")
    end

    it "raises ArgumentError for an unknown analyzer" do
      expect {
        index.analyze_text(analyzer: "nonexistent_analyzer", text: "hello")
      }.to raise_error(ArgumentError, /does not exist/)
    end
  end

  describe "#analyze_text_field" do
    let(:field_mappings) do
      {
        mappings: {
          properties: {
            body: {
              type: "text",
              analyzer: "test_lower"
            }
          }
        }
      }
    end

    before { index.update_mappings(field_mappings) }

    it "analyzes text using the field's configured analyzer" do
      tokens = index.analyze_text_field(field: "body", text: "Hello World")
      expect(tokens).to include("hello", "world")
    end

    it "raises ArgumentError for a field that does not exist in the mapping" do
      expect {
        index.analyze_text_field(field: "nonexistent_field", text: "hello")
      }.to raise_error(ArgumentError, /does not exist/)
    end

    it "raises ArgumentError for a field with no analyzer configured" do
      # Add a keyword field (no analyzer) and try to analyze it
      index.update_mappings({mappings: {properties: {status: {type: "keyword"}}}})
      expect {
        index.analyze_text_field(field: "status", text: "hello")
      }.to raise_error(ArgumentError, /No analyzer/)
    end
  end
end
