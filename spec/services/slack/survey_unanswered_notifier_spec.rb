require "rails_helper"

RSpec.describe "Slack::SurveyUnansweredNotifier" do
  before do
    Question.ensure_standard_questions!
  end

  it "posts unanswered users to configured webhook" do
    survey = Survey.create!(title: "通知テスト", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    users = [
      User.create!(name: "未回答A", email: "first@example.com", slack_user_id: "U12345678", survey_subject: true),
      User.create!(name: "未回答B", email: "second@example.com", slack_user_id: "U23456789", survey_subject: true)
    ]
    http_client = FakeHttpClient.success

    assert Slack::SurveyUnansweredNotifier.call(
      survey: survey,
      users: users,
      webhook_url: "https://example.com/slack-webhook",
      http_client: http_client
    )

    uri, body, headers = http_client.requests.first
    payload = JSON.parse(body)

    assert_equal "https://example.com/slack-webhook", uri.to_s
    assert_equal "application/json", headers.fetch("Content-Type")
    assert_equal "サーベイ未回答者: 2名", payload.fetch("text")
    assert_equal <<~TEXT.chomp, payload.dig("blocks", 0, "text", "text")
      以下の方は今週のサーベイ回答が完了していません。
      本日 24:00 までに回答をしてください。
      #{Rails.application.config.app_settings.fetch(:service_url)}

      - <@U12345678>
      - <@U23456789>

      ※ この通知を認識したら、リアクションをお願いします。
    TEXT
  end

  it "raises when webhook is not configured" do
    survey = Survey.create!(title: "通知テスト", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assert_raises Slack::SurveyUnansweredNotifier::ConfigurationError do
      Slack::SurveyUnansweredNotifier.call(survey: survey, users: [], webhook_url: nil)
    end
  end

  it "raises when slack returns non success response" do
    survey = Survey.create!(title: "通知テスト", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assert_raises Slack::SurveyUnansweredNotifier::DeliveryError do
      Slack::SurveyUnansweredNotifier.call(
        survey: survey,
        users: [],
        webhook_url: "https://example.com/slack-webhook",
        http_client: FakeHttpClient.failure
      )
    end
  end

  class FakeHttpClient
    attr_reader :requests

    def self.success
      new(Net::HTTPSuccess.new("1.1", "200", "OK"))
    end

    def self.failure
      new(Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error"))
    end

    def initialize(response)
      @response = response
      @requests = []
    end

    def post(uri, body, headers)
      requests << [ uri, body, headers ]

      @response
    end
  end
end
