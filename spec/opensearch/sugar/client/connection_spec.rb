# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenSearch::Sugar::Client, "connection" do
  include_context "opensearch client"

  describe "#ping (via SimpleDelegator)" do
    it "successfully connects to the OpenSearch cluster" do
      expect(client.ping).to be true
    end
  end

  describe "#raw_client" do
    it "exposes the underlying OpenSearch::Client instance" do
      expect(client.raw_client).to be_a(OpenSearch::Client)
    end
  end

  describe "OpenSearch::Sugar.new" do
    it "returns an OpenSearch::Sugar::Client" do
      expect(OpenSearch::Sugar.new).to be_a(OpenSearch::Sugar::Client)
    end
  end
end
