require "test_helper"
require "fugit"
require "yaml"

class ApplicationConfigurationTest < ActiveSupport::TestCase
  test "uses Tokyo time zone" do
    assert_equal "Tokyo", Time.zone.name
  end

  test "schedules unanswered survey notification every Thursday at 18:00" do
    recurring_config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    schedule = recurring_config.dig("production", "survey_unanswered_notification")

    assert_equal "SurveyUnansweredNotificationJob", schedule.fetch("class")
    assert_equal "default", schedule.fetch("queue")
    assert_equal "0 18 * * 4", Fugit.parse(schedule.fetch("schedule")).original
  end
end
