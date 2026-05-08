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

  describe "#test_analyzer_by_name" do
    it "returns the tokens produced by the analyzer" do
      tokens = index.test_analyzer_by_name(analyzer: "test_lower", text: "Hello World")
      expect(tokens).to include("hello", "world")
    end

    it "lowercases tokens with the test_lower analyzer" do
      tokens = index.test_analyzer_by_name(analyzer: "test_lower", text: "ALLCAPS")
      expect(tokens).to include("allcaps")
    end

    it "raises ArgumentError for an unknown analyzer" do
      expect {
        index.test_analyzer_by_name(analyzer: "nonexistent_analyzer", text: "hello")
      }.to raise_error(ArgumentError, /does not exist/)
    end

    it "is aliased as #analyze_text" do
      expect(index.method(:analyze_text)).to eq(index.method(:test_analyzer_by_name))
    end
  end

  describe "#test_analyzer_by_name with same-position tokens" do
    let(:synonym_settings) do
      {
        settings: {
          analysis: {
            filter: {
              synonym_filter: {
                type: "synonym",
                synonyms: ["quick, fast"]
              }
            },
            analyzer: {
              synonym_lower: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase", "synonym_filter"]
              }
            }
          }
        }
      }
    end
    let(:synonym_index_name) { "sugar_test_#{SecureRandom.hex(6)}" }
    let(:synonym_index) do
      idx = OpenSearch::Sugar::Index.create(client: client, name: synonym_index_name)
      idx.update_settings(synonym_settings)
      idx
    end

    before { synonym_index }
    after { client.delete_index!(synonym_index_name) rescue nil }

    it "returns same-position tokens as arrays when a synonym filter expands terms" do
      tokens = synonym_index.test_analyzer_by_name(analyzer: "synonym_lower", text: "quick")
      # "quick" expands to both "quick" and "fast" at the same position
      expect(tokens).to satisfy { |t| t.any? { |tok| tok.is_a?(Array) } }
        .or include(["quick", "fast"].sort)
        .or include(["fast", "quick"].sort)
    end
  end

  describe "#test_analyzer_by_fieldname" do
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
      tokens = index.test_analyzer_by_fieldname(field: "body", text: "Hello World")
      expect(tokens).to include("hello", "world")
    end

    it "raises ArgumentError for a field that does not exist in the mapping" do
      expect {
        index.test_analyzer_by_fieldname(field: "nonexistent_field", text: "hello")
      }.to raise_error(ArgumentError, /does not exist/)
    end

    it "raises ArgumentError for a field with no analyzer configured" do
      # Add a keyword field (no analyzer) and try to analyze it
      index.update_mappings({mappings: {properties: {status: {type: "keyword"}}}})
      expect {
        index.test_analyzer_by_fieldname(field: "status", text: "hello")
      }.to raise_error(ArgumentError, /No analyzer/)
    end

    it "is aliased as #analyze_text_field" do
      expect(index.method(:analyze_text_field)).to eq(index.method(:test_analyzer_by_fieldname))
    end
  end
end
