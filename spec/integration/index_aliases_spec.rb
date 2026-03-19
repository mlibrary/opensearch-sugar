# frozen_string_literal: true

require "integration_helper"

RSpec.describe "Index Aliases", integration: true do
  describe "#aliases" do
    it "returns empty array for index with no aliases" do
      index_name = "test_no_aliases_#{Time.now.to_i}"
      index = create_test_index(index_name)
      expect(index.aliases).to eq([])
    end
  end

  describe "#create_alias" do
    it "creates an alias for the index" do
      index_name = "test_create_alias_#{Time.now.to_i}"
      index = create_test_index(index_name)
      index.create_alias("test_alias_#{Time.now.to_i}")
      expect(index.aliases.size).to eq(1)
    end

    it "returns all aliases after creating new one" do
      index_name = "test_multiple_aliases_#{Time.now.to_i}"
      index = create_test_index(index_name)
      timestamp = Time.now.to_i
      alias1 = "alias1_#{timestamp}"
      alias2 = "alias2_#{timestamp}"
      
      index.create_alias(alias1)
      aliases = index.create_alias(alias2)
      expect(aliases).to contain_exactly(alias1, alias2)
    end

    it "can create multiple aliases for the same index" do
      index_name = "test_many_aliases_#{Time.now.to_i}"
      index = create_test_index(index_name)
      timestamp = Time.now.to_i

      3.times do |i|
        index.create_alias("alias_#{i}_#{timestamp}")
      end

      expect(index.aliases.size).to eq(3)
    end
  end
end

