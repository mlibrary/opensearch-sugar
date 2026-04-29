# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Models, "registration", :models, :slow do
  include_context "opensearch client"

  let(:models) { client.models }
  let(:model_name) { "huggingface/sentence-transformers/all-MiniLM-L12-v2" }
  let(:model_version) { "1.0.1" }

  after do
    models.delete!(model_name) rescue nil
  end

  describe "#register" do
    it "registers and deploys the model, returning an ML_INFO struct" do
      model = models.register(name: model_name, version: model_version)
      expect(model).to be_a(OpenSearch::Sugar::Models::ML_INFO)
      expect(model.name).to eq(model_name)
      expect(model.id).not_to be_nil
    end

    it "is idempotent — returns the existing model if already registered" do
      first = models.register(name: model_name, version: model_version)
      second = models.register(name: model_name, version: model_version)
      expect(first.id).to eq(second.id)
    end
  end

  describe "#deploy (alias)" do
    it "is an alias for #register" do
      expect(models.method(:deploy)).to eq(models.method(:register))
    end
  end
end
