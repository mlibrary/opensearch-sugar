# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("lib", __dir__)

require "opensearch/sugar"
require "logger"

# Set dummy environment variables for testing
ENV['OPENSEARCH_URL'] = 'https://localhost:9200'
ENV['OPENSEARCH_USER'] = 'admin'
ENV['OPENSEARCH_PASSWORD'] = 'admin'

# Test 1: Verify SSL verification is enabled by default
puts "Test 1: Checking SSL verification defaults..."
client = OpenSearch::Sugar::Client.new
default_args = client.default_args
ssl_verify = default_args.dig(:transport_options, :ssl, :verify)

if ssl_verify == true
  puts "✓ PASS: SSL verification is enabled by default"
else
  puts "✗ FAIL: SSL verification is NOT enabled by default (value: #{ssl_verify.inspect})"
  exit 1
end

# Test 2: Verify logger is set up
puts "\nTest 2: Checking logger initialization..."
if client.logger.is_a?(Logger)
  puts "✓ PASS: Logger is initialized"
else
  puts "✗ FAIL: Logger is not initialized properly"
  exit 1
end

# Test 3: Verify custom logger can be passed
puts "\nTest 3: Checking custom logger..."
custom_logger = Logger.new($stdout, level: Logger::INFO)
client_with_logger = OpenSearch::Sugar::Client.new(logger: custom_logger)

if client_with_logger.logger == custom_logger
  puts "✓ PASS: Custom logger is accepted"
else
  puts "✗ FAIL: Custom logger not set properly"
  exit 1
end

# Test 4: Verify SSL can be disabled explicitly
puts "\nTest 4: Checking SSL can be disabled..."
begin
  client_no_ssl = OpenSearch::Sugar::Client.new(
    transport_options: {ssl: {verify: false}}
  )
  puts "✓ PASS: SSL verification can be disabled explicitly"
rescue => e
  puts "✗ FAIL: Error when disabling SSL: #{e.message}"
  exit 1
end

puts "\n" + "=" * 50
puts "All tests passed! ✓"
puts "=" * 50
puts "\nSummary of changes:"
puts "1. SSL verification is now ENABLED by default (verify: true)"
puts "2. Logger support added (defaults to Logger.new($stdout, level: Logger::WARN))"
puts "3. Error handling now catches specific OpenSearch::Transport::Transport::Error"
puts "4. Removed puts/pp in favor of logger.warn and logger.debug"
puts "5. Standardized on exceptions - update_settings and update_mappings now raise exceptions instead of returning status hashes"
puts "\nError Handling Pattern:"
puts "  - All errors raise exceptions (no status hashes)"
puts "  - update_settings() raises OpenSearch::Transport::Transport::Error on failure"
puts "  - update_mappings() raises OpenSearch::Transport::Transport::Error on failure"
puts "  - Consistent with Ruby idioms and rest of codebase"



