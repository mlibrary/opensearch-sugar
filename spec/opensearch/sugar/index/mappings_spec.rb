# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Index, "mappings" do
  include_context "opensearch client"

  let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }
  let(:index) { OpenSearch::Sugar::Index.create(client: client, name: index_name) }

  before { index }

  after {
    begin
      client.delete_index!(index_name)
    rescue
      nil
    end
  }

  describe "#mappings" do
    it "returns a Hash" do
      expect(index.mappings).to be_a(Hash)
    end

    it "includes the index name as a top-level key" do
      expect(index.mappings).to have_key(index_name)
    end
  end

  describe "#update_mappings" do
    let(:new_mappings) do
      {
        mappings: {
          properties: {
            title: {type: "text"},
            created_at: {type: "date"}
          }
        }
      }
    end

    it "applies mappings without raising" do
      expect { index.update_mappings(new_mappings) }.not_to raise_error
    end

    it "makes the new fields visible in mappings after the update" do
      index.update_mappings(new_mappings)
      props = index.mappings.dig(index_name, "mappings", "properties")
      expect(props).to include("title", "created_at")
    end

    it "raises OpenSearch::Sugar::Error when given an invalid mapping" do
      bad_mapping = {mappings: {properties: {bad_field: {type: "not_a_real_type"}}}}
      expect {
        index.update_mappings(bad_mapping)
      }.to raise_error(OpenSearch::Sugar::Error)
    end

    it "leaves the index open after a failed update" do
      bad_mapping = {mappings: {properties: {bad_field: {type: "not_a_real_type"}}}}
      begin
        index.update_mappings(bad_mapping)
      rescue OpenSearch::Sugar::Error
        # expected — testing that the index is still accessible after the failure
      end
      expect { index.count }.not_to raise_error
    end
  end
end
