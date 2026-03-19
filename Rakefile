# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--tag ~integration"
end

RSpec::Core::RakeTask.new(:integration) do |t|
  t.rspec_opts = "--tag integration --format documentation"
end

require "standard/rake"

task default: %i[spec standard]

namespace :docker do
  desc "Start OpenSearch container"
  task :start do
    sh "docker compose up -d opensearch"
    puts "Waiting for OpenSearch to be healthy..."
    30.times do
      if system("docker compose ps opensearch | grep -q healthy")
        puts "✓ OpenSearch is ready"
        break
      end
      print "."
      sleep 2
    end
  end

  desc "Stop all Docker containers"
  task :stop do
    sh "docker compose down"
  end

  desc "Restart OpenSearch container"
  task :restart do
    sh "docker compose restart opensearch"
  end

  desc "Show OpenSearch logs"
  task :logs do
    sh "docker compose logs -f opensearch"
  end

  desc "Start a shell in the Ruby container"
  task :shell do
    sh "docker compose exec ruby bash"
  end

  desc "Start a console in the Ruby container"
  task :console do
    sh "docker compose exec ruby bash -c 'RUN_INTEGRATION_TESTS=true bundle exec bin/console'"
  end

  desc "Rebuild containers"
  task :build do
    sh "docker compose build"
  end

  desc "Rebuild containers without cache"
  task :rebuild do
    sh "docker compose build --no-cache"
  end

  desc "Run RSpec inside ruby container (for debugging specific tests)"
  task :rspec, [:args] do |t, args|
    rspec_args = args[:args] || ""
    sh "docker compose exec ruby bash -c 'RUN_INTEGRATION_TESTS=true bundle exec rspec #{rspec_args}'"
  end
end

desc "Run integration tests (starts OpenSearch if needed)"
task :test_integration do
  # Ensure containers are up
  sh "docker compose up -d opensearch ruby"
  
  puts "Waiting for OpenSearch to be healthy..."
  30.times do
    if system("docker compose ps opensearch | grep -q healthy", out: File::NULL, err: File::NULL)
      puts "✓ OpenSearch is ready"
      break
    end
    print "."
    sleep 2
  end
  
  # Run tests inside the ruby container
  sh "docker compose exec -T ruby bash -c 'RUN_INTEGRATION_TESTS=true bundle exec rake integration'"
end

desc "Run all tests (unit + integration)"
task test: %i[spec test_integration]


