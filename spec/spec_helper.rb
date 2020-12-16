# frozen_string_literal: true

require 'bundler/setup'
require 'webmock/rspec'

require_relative '../lib/obs_deploy'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

WebMock.disable_net_connect!

Dir['./spec/support/shared_contexts/*.rb'].sort.each { |file| require file }
