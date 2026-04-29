# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe OpenSearch::Sugar::Index, "documents" do
  include_context "opensearch client"

  let(:index_name) { "sugar_test_#{SecureRandom.hex(6)}" }
  let(:index) { OpenSearch::Sugar::Index.create(client: client, name: index_name) }

  before { index } # ensure index is created

  after do
    client.delete_index!(index_name) rescue nil
  end

  # Force a refresh so newly indexed docs are immediately searchable
  def refresh
    index.refresh
  end

  describe "#count" do
    it "returns 0 for an empty index" do
      expect(index.count).to eq(0)
    end

    it "returns the correct count after indexing documents" do
      index.index_document({title: "doc1"}, "1")
      index.index_document({title: "doc2"}, "2")
      refresh
      expect(index.count).to eq(2)
    end
  end

  describe "#index_document" do
    it "makes the document retrievable" do
      index.index_document({title: "hello"}, "doc-1")
      refresh
      expect(index.count).to eq(1)
    end
  end

  describe "#delete_by_id" do
    before { index.index_document({title: "to delete"}, "target"); refresh }

    it "removes the document from the index" do
      index.delete_by_id("target")
      refresh
      expect(index.count).to eq(0)
    end

    it "raises ArgumentError if id is nil" do
      expect { index.delete_by_id(nil) }.to raise_error(ArgumentError, /nil or empty/)
    end

    it "raises ArgumentError if id is empty string" do
      expect { index.delete_by_id("") }.to raise_error(ArgumentError, /nil or empty/)
    end
  end

  describe "#clear!" do
    before do
      index.index_document({title: "a"}, "1")
      index.index_document({title: "b"}, "2")
      refresh
    end

    it "returns the number of deleted documents" do
      deleted = index.clear!
      expect(deleted).to eq(2)
    end

    it "leaves the index empty" do
      index.clear!
      refresh
      expect(index.count).to eq(0)
    end
  end

  describe "#index_jsonl_file" do
    let(:jsonl) do
      StringIO.new(
        [{id: "a1", text: "first"}, {id: "a2", text: "second"}]
          .map(&:to_json)
          .join("\n") + "\n"
      )
    end

    it "indexes all documents from the IO source" do
      index.index_jsonl_file(jsonl, id_field: :id)
      refresh
      expect(index.count).to eq(2)
    end

    it "raises ArgumentError when a document is missing the id_field" do
      bad_jsonl = StringIO.new({name: "no id here"}.to_json + "\n")
      expect {
        index.index_jsonl_file(bad_jsonl, id_field: :id)
      }.to raise_error(ArgumentError, /id_field :id not found/)
    end

    context "with a file path" do
      let(:tmp_file) do
        f = Tempfile.new(["sugar_test", ".jsonl"])
        f.write([{id: "f1", text: "from file"}].map(&:to_json).join("\n") + "\n")
        f.flush
        f
      end

      after { tmp_file.close; tmp_file.unlink }

      it "reads the file and indexes documents" do
        index.index_jsonl_file(tmp_file.path, id_field: :id)
        refresh
        expect(index.count).to eq(1)
      end
    end
  end
end
