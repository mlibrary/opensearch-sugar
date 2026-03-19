# frozen_string_literal: true

require "integration_helper"

RSpec.describe "Index Analysis", integration: true do
  let(:test_settings) do
    {
      analysis: {
        analyzer: {
          my_custom_analyzer: {
            type: "custom",
            tokenizer: "standard",
            filter: %w[lowercase asciifolding]
          },
          my_simple_analyzer: {
            type: "simple"
          }
        }
      }
    }
  end

  let(:test_mappings) do
    {
      properties: {
        title: {
          type: "text",
          analyzer: "my_custom_analyzer"
        },
        description: {
          type: "text",
          analyzer: "standard"
        }
      }
    }
  end

  describe "#all_available_analyzers" do
    it "returns list of custom analyzers (empty for new index)" do
      index_name = "test_analyzers_#{Time.now.to_i}"
      index = create_test_index(index_name)
      analyzers = index.all_available_analyzers
      expect(analyzers).to be_an(Array)
      # New indexes have no custom analyzers
      expect(analyzers).to be_empty
    end

    it "includes custom analyzers after settings update" do
      index_name = "test_custom_analyzers_#{Time.now.to_i}"
      index = create_test_index(index_name)
      index.update_settings(test_settings)
      
      analyzers = index.all_available_analyzers
      expect(analyzers).to include("my_custom_analyzer")
      expect(analyzers).to include("my_simple_analyzer")
    end

    it "aliases to #analyzers method" do
      index_name = "test_analyzers_alias_#{Time.now.to_i}"
      index = create_test_index(index_name)
      expect(index.analyzers).to eq(index.all_available_analyzers)
    end
  end

  describe "#analyze_text" do
    it "analyzes text with standard analyzer" do
      index_name = "test_analyze_standard_#{Time.now.to_i}"
      index = create_test_index(index_name)
      
      tokens = index.analyze_text(analyzer: "standard", text: "Hello World!")
      expect(tokens).to include("hello", "world")
      expect(tokens).not_to include("!")
    end

    it "analyzes text with custom analyzer after settings update" do
      index_name = "test_analyze_custom_#{Time.now.to_i}"
      index = create_test_index(index_name)
      index.update_settings(test_settings)

      tokens = index.analyze_text(analyzer: "my_custom_analyzer", text: "Café Résumé")
      expect(tokens).to all(be_a(String))
    end

    it "raises error for non-existent analyzer" do
      index_name = "test_bad_analyzer_#{Time.now.to_i}"
      index = create_test_index(index_name)
      expect {
        index.analyze_text(analyzer: "nonexistent_analyzer", text: "test")
      }.to raise_error(ArgumentError, /does not exist/)
    end

    it "handles empty text" do
      index_name = "test_analyze_empty_#{Time.now.to_i}"
      index = create_test_index(index_name)
      tokens = index.analyze_text(analyzer: "standard", text: "")
      expect(tokens).to eq([])
    end

    it "handles text with only stopwords" do
      index_name = "test_analyze_stopwords_#{Time.now.to_i}"
      index = create_test_index(index_name)
      # Standard analyzer doesn't remove stopwords by default, but test the behavior
      tokens = index.analyze_text(analyzer: "standard", text: "the a an")
      expect(tokens).to be_an(Array)
    end
  end

  describe "#analyze_text_field" do
    it "analyzes text using field's analyzer" do
      index_name = "test_field_analyzer_#{Time.now.to_i}"
      index = create_test_index(index_name)
      index.update_settings(test_settings)
      index.update_mappings(test_mappings)

      tokens = index.analyze_text_field(field: "title", text: "Hello World")
      expect(tokens).to include("hello", "world")
    end

    it "uses different analyzers for different fields" do
      index_name = "test_different_analyzers_#{Time.now.to_i}"
      index = create_test_index(index_name)
      index.update_settings(test_settings)
      index.update_mappings(test_mappings)

      # title uses my_custom_analyzer (with asciifolding)
      title_tokens = index.analyze_text_field(field: "title", text: "Café")
      # description uses standard analyzer
      desc_tokens = index.analyze_text_field(field: "description", text: "Café")

      expect(title_tokens).to be_an(Array)
      expect(desc_tokens).to be_an(Array)
    end

    it "raises error for non-existent field" do
      index_name = "test_bad_field_#{Time.now.to_i}"
      index = create_test_index(index_name)
      expect {
        index.analyze_text_field(field: "nonexistent", text: "test")
      }.to raise_error(ArgumentError, /does not exist/)
    end

    it "raises error for field without analyzer" do
      index_name = "test_no_analyzer_field_#{Time.now.to_i}"
      index = create_test_index(index_name)
      
      # Create a mapping with a keyword field (no analyzer)
      mappings = {
        properties: {
          id: {type: "keyword"}
        }
      }
      index.update_mappings(mappings)

      expect {
        index.analyze_text_field(field: "id", text: "test")
      }.to raise_error(ArgumentError, /No analyzer/)
    end
  end
end

