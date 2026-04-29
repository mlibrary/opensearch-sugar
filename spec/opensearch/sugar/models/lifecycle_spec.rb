# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Models, "lifecycle", :models, :slow do
  include_context "opensearch client"

  let(:models) { client.models }
  let(:model_name) { "huggingface/sentence-transformers/all-MiniLM-L12-v2" }
  let(:model_version) { "1.0.1" }

  describe "#undeploy!" do
    before { models.register(name: model_name, version: model_version) }
    after  { models.delete!(model_name) rescue nil }

    it "undeploys the model without raising" do
      expect { models.undeploy!(model_name) }.not_to raise_error
    end
  end

  describe "#delete!" do
    before { models.register(name: model_name, version: model_version) }

    it "removes the model so it no longer appears in the list" do
      models.delete!(model_name)
      expect(models.list.map(&:name)).not_to include(model_name)
    end

    it "the model is not findable via [] after deletion" do
      models.delete!(model_name)
      expect(models[model_name]).to be_nil
    end
  end
end
