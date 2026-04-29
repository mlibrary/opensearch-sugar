# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Index, "settings" do
  include_context "opensearch client"

  let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }
  let(:index) { OpenSearch::Sugar::Index.create(client: client, name: index_name) }

  before { index }

  after { client.delete_index!(index_name) rescue nil }

  describe "#settings" do
    it "returns a Hash" do
      expect(index.settings).to be_a(Hash)
    end

    it "includes the index name as a top-level key" do
      expect(index.settings).to have_key(index_name)
    end
  end

  describe "#update_settings" do
    let(:analyzer_settings) do
      {
        settings: {
          analysis: {
            analyzer: {
              test_analyzer: {
                type: "custom",
                tokenizer: "standard",
                filter: ["lowercase"]
              }
            }
          }
        }
      }
    end

    it "applies index-level settings without raising" do
      expect { index.update_settings(analyzer_settings) }.not_to raise_error
    end

    it "makes the new analyzer available after the update" do
      index.update_settings(analyzer_settings)
      expect(index.all_available_analyzers).to include("test_analyzer")
    end

    it "raises OpenSearch::Sugar::Error when given an invalid setting" do
      expect {
        index.update_settings({settings: {index: {nonexistent_setting_xyz: "bad"}}})
      }.to raise_error(OpenSearch::Sugar::Error)
    end

    it "leaves the index open (accessible) after a failed update" do
      begin
        index.update_settings({settings: {index: {nonexistent_setting_xyz: "bad"}}})
      rescue OpenSearch::Sugar::Error
        # expected — testing that the index is still accessible after the failure
      end
      expect { index.count }.not_to raise_error
    end
  end
end
