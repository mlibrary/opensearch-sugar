# frozen_string_literal: true

require "spec_helper"

# Tests Client#update_settings with cluster-level settings.
# Index-level settings (e.g. analyzers) are tested via Index#update_settings
# in spec/opensearch/sugar/index/settings_spec.rb.
RSpec.describe OpenSearch::Sugar::Client, "cluster settings" do
  include_context "opensearch client"

  # cluster.routing.allocation.enable is a benign, fully reversible cluster setting.
  # "none"  — disables shard allocation
  # "all"   — re-enables shard allocation (the default)
  let(:disable_allocation) { {persistent: {"cluster.routing.allocation.enable" => "none"}} }
  let(:enable_allocation)  { {persistent: {"cluster.routing.allocation.enable" => "all"}} }

  after { client.cluster.put_settings(body: enable_allocation) rescue nil }

  describe "#update_settings with a cluster-level setting" do
    it "does not raise when disabling shard allocation" do
      expect { client.cluster.put_settings(body: disable_allocation) }.not_to raise_error
    end

    it "the setting is visible via cluster.get_settings after applying" do
      client.cluster.put_settings(body: disable_allocation)
      value = client.cluster.get_settings.dig("persistent", "cluster", "routing", "allocation", "enable")
      expect(value).to eq("none")
    end

    it "restores the setting successfully" do
      client.cluster.put_settings(body: disable_allocation)
      client.cluster.put_settings(body: enable_allocation)
      value = client.cluster.get_settings.dig("persistent", "cluster", "routing", "allocation", "enable")
      expect(value).to eq("all").or be_nil # nil means reset to default
    end
  end

  describe "#set_log_level" do
    it "does not raise when setting a valid log level" do
      expect { client.set_log_level(logger: "logger._root", level: "warn") }.not_to raise_error
    end
  end
end
