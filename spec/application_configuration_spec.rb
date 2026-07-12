require "rails_helper"
require "fugit"
require "yaml"

RSpec.describe "ApplicationConfiguration" do
  it "uses Tokyo time zone" do
    assert_equal "Tokyo", Time.zone.name
  end

  it "loads service url from app settings" do
    assert_equal "http://localhost:3000", Rails.application.config.app_settings.fetch(:service_url)
  end

  it "schedules unanswered survey notification every Thursday at 18:00" do
    recurring_config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    schedule = recurring_config.dig("production", "survey_unanswered_notification")

    assert_equal "SurveyUnansweredNotificationJob", schedule.fetch("class")
    assert_equal "default", schedule.fetch("queue")
    assert_equal "0 18 * * 4", Fugit.parse(schedule.fetch("schedule")).original
  end
end
