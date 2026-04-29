# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Models, "lookup", :models, :slow do
  include_context "opensearch client"

  let(:models) { client.models }
  let(:model_name) { "huggingface/sentence-transformers/all-MiniLM-L12-v2" }
  let(:model_version) { "1.0.1" }
  let!(:registered_model) { models.register(name: model_name, version: model_version) }

  after {
    begin
      models.delete!(model_name)
    rescue
      nil
    end
  }

  describe "#list" do
    it "returns an Array" do
      expect(models.list).to be_an(Array)
    end

    it "includes the registered model" do
      expect(models.list.map(&:name)).to include(model_name)
    end

    it "returns ML_INFO structs" do
      expect(models.list).to all(be_a(OpenSearch::Sugar::Models::ML_INFO))
    end
  end

  describe "#[]" do
    it "finds the model by exact name" do
      result = models[model_name]
      expect(result).to be_a(OpenSearch::Sugar::Models::ML_INFO)
      expect(result.name).to eq(model_name)
    end

    it "finds the model by its ID" do
      result = models[registered_model.id]
      expect(result.id).to eq(registered_model.id)
    end

    it "finds the model by a partial name (case-insensitive)" do
      result = models["all-minilm"]  # all lowercase — verifies case-insensitive matching
      expect(result).not_to be_nil
      expect(result.name).to include("MiniLM")
    end

    it "returns nil for an unknown identifier" do
      expect(models["completely_unknown_model_xyz"]).to be_nil
    end
  end
end
