# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Client, "analyzer" do
  include_context "opensearch client"

  describe "#test_analyzer_by_definition" do
    it "tokenizes text using a transient tokenizer and token filter" do
      tokens = client.test_analyzer_by_definition(
        text: "Hello World",
        tokenizer: "standard",
        filter: ["lowercase"]
      )
      expect(tokens).to eq(["hello", "world"])
    end

    it "applies character filters before tokenization" do
      tokens = client.test_analyzer_by_definition(
        text: "<b>Hello</b> World",
        tokenizer: "standard",
        char_filter: ["html_strip"],
        filter: ["lowercase"]
      )
      expect(tokens).to eq(["hello", "world"])
    end

    it "works with only a tokenizer and no filters" do
      tokens = client.test_analyzer_by_definition(
        text: "Hello World",
        tokenizer: "standard"
      )
      expect(tokens).to include("Hello", "World")
    end

    it "raises ArgumentError when tokenizer is nil" do
      expect {
        client.test_analyzer_by_definition(text: "hello", tokenizer: nil)
      }.to raise_error(ArgumentError, /tokenizer/)
    end

    it "raises ArgumentError when tokenizer is empty" do
      expect {
        client.test_analyzer_by_definition(text: "hello", tokenizer: "")
      }.to raise_error(ArgumentError, /tokenizer/)
    end
  end
end
