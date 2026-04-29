# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Models, "pipeline", :models, :slow do
  include_context "opensearch client"

  let(:models) { client.models }
  let(:model_name) { "huggingface/sentence-transformers/all-MiniLM-L12-v2" }
  let(:model_version) { "1.0.1" }
  let(:pipeline_name) { "sugar_test_pipeline_#{SecureRandom.hex(6)}" }
  let!(:registered_model) { models.register(name: model_name, version: model_version) }

  after do
    client.models.delete_pipeline!(pipeline_name) rescue nil
    models.delete!(model_name) rescue nil
  end

  describe "#create_pipeline" do
    it "creates the ingest pipeline without raising" do
      expect {
        models.create_pipeline(
          name: pipeline_name,
          model: model_name,
          description: "Test embedding pipeline",
          field_map: {"text" => "text_embedding"}
        )
      }.not_to raise_error
    end

    it "raises if the model cannot be found" do
      expect {
        models.create_pipeline(
          name: pipeline_name,
          model: "nonexistent_model_xyz",
          description: "Should fail",
          field_map: {"text" => "text_embedding"}
        )
      }.to raise_error(RuntimeError, /Can't find model/)
    end
  end
end
