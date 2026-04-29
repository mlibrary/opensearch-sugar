# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

YARD::Rake::YardocTask.new(:yard) do |t|
  t.files = ["lib/**/*.rb"]
  t.options = ["--output-dir", "doc/", "--markup", "markdown"]
end

task default: %i[spec standard]
