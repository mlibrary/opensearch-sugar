# frozen_string_literal: true

# Load environment variables from spec/env.spec
require "dotenv"

ENV_FILE = File.join(__dir__, "env.spec")
if !(File.exist?(ENV_FILE)) 
  $stderr.puts "Can't find spec/env.spec. Exiting"
  exit 1
end

Dotenv.load(ENV_FILE)


require "opensearch/sugar"
require "timecop"

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Filter integration tests with tag
  config.filter_run_excluding integration: true unless ENV["RUN_INTEGRATION_TESTS"]

  # Colorize output
  config.color = true

  # Use documentation format for verbose output
  config.default_formatter = "doc" if config.files_to_run.one?

  # Clean up after Timecop usage
  config.after(:each) do
    Timecop.return
  end
end
