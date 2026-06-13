require "json"
require "net/http"
require "uri"

module Slack
  class SurveyUnansweredNotifier
    WEBHOOK_ENV_KEY = "SLACK_SURVEY_WEBHOOK_URL"

    class ConfigurationError < StandardError; end
    class DeliveryError < StandardError; end

    def self.call(survey:, users:, webhook_url: ENV[WEBHOOK_ENV_KEY], http_client: Net::HTTP)
      new(survey: survey, users: users, webhook_url: webhook_url, http_client: http_client).call
    end

    def self.configured?
      ENV[WEBHOOK_ENV_KEY].present?
    end

    def initialize(survey:, users:, webhook_url:, http_client:)
      @survey = survey
      @users = users.to_a
      @webhook_url = webhook_url
      @http_client = http_client
    end

    def call
      raise ConfigurationError, "#{WEBHOOK_ENV_KEY} is not configured" if webhook_url.blank?

      response = http_client.post(
        URI.parse(webhook_url),
        JSON.generate(payload),
        "Content-Type" => "application/json"
      )

      raise DeliveryError, "Slack webhook returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      true
    end

    private

    attr_reader :survey, :users, :webhook_url, :http_client

    def payload
      {
        text: fallback_text,
        blocks: [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: message_text
            }
          }
        ]
      }
    end

    def fallback_text
      "サーベイ未回答者: #{users.size}名"
    end

    def message_text
      return "未回答者はいません。" if users.empty?

      [
        users.map { |user| "<@#{user.slack_user_id}>" }.join(" "),
        "今週のサーベイへの回答がまだ完了していません。",
        "回答をお願いします。"
      ].join("\n")
    end
  end
end
