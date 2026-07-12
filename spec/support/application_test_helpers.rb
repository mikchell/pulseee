# frozen_string_literal: true

module ApplicationTestHelpers
  attr_accessor :assertions

  def create_standard_questions
    Question.ensure_standard_questions!
  end

  def assert_not_equal(expected, actual, message = nil)
    assert expected != actual, message || "Expected #{actual.inspect} to not equal #{expected.inspect}"
  end

  def assert_not_includes(collection, object, message = nil)
    assert !collection.include?(object), message || "Expected #{collection.inspect} to not include #{object.inspect}"
  end

  def assert_not_nil(object, message = nil)
    assert !object.nil?, message || "Expected #{object.inspect} to not be nil"
  end

  def assert_no_match(pattern, string, message = nil)
    assert !pattern.match?(string), message || "Expected #{string.inspect} to not match #{pattern.inspect}"
  end
end

RSpec.configure do |config|
  config.include ApplicationTestHelpers
end
