# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Integration tests (require OpenSearch to be running)
RSpec::Core::RakeTask.new(:integration) do |t|
  ENV["RUN_INTEGRATION_TESTS"] = "true"
  t.pattern = "spec/integration/**/*_spec.rb"
  t.rspec_opts = "--format documentation"
end

# Unit tests only (exclude integration tests)
RSpec::Core::RakeTask.new(:unit) do |t|
  t.pattern = "spec/**/*_spec.rb"
  t.exclude_pattern = "spec/integration/**/*_spec.rb"
end

require "standard/rake"

task default: %i[unit standard]
