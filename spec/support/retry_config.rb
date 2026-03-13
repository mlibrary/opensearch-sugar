# frozen_string_literal: true

require "rspec/retry"
RSpec.configure do |config|
  # Show retry status in spec output
  config.verbose_retry = true
  # Show retry exception in spec output
  config.display_try_failure_messages = true
  # Run integration tests with retry on failure (network issues, timing issues)
  config.around(:each, type: :integration) do |example|
    example.run_with_retry retry: 3, retry_wait: 1
  end
  # Specific retry configuration for search tests (eventual consistency)
  config.around(:each, :retry_on_search) do |example|
    example.run_with_retry retry: 5, retry_wait: 0.5
  end
  # Retry configuration for cluster operations
  config.around(:each, :retry_on_cluster) do |example|
    example.run_with_retry retry: 3, retry_wait: 2
  end
end
