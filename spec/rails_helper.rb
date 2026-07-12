# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "spec_helper"
require "rspec/rails"
require "active_job/test_helper"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |file| require file }

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures").to_s ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::Assertions
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActionDispatch::Assertions::ResponseAssertions, type: :request
  config.include ActionDispatch::Assertions::RoutingAssertions, type: :request
  config.include ActionDispatch::Assertions::SelectorAssertions, type: :request

  config.before do
    self.assertions = 0 if respond_to?(:assertions=)
  end

  config.after do
    travel_back
    clear_enqueued_jobs if respond_to?(:clear_enqueued_jobs)
    clear_performed_jobs if respond_to?(:clear_performed_jobs)
  end
end
