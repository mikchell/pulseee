module Surveys
  class CreateCurrentWeekSurvey
    class NotCreationDayError < StandardError; end

    def self.call(now: Time.current)
      new(now: now).call
    end

    def self.current_period(now: Time.current)
      date = now.in_time_zone.to_date
      return nil unless date.thursday?

      start_at = date.in_time_zone

      [ start_at, start_at + 2.days ]
    end

    def self.current_survey(now: Time.current)
      period = current_period(now: now)
      return nil unless period

      start_at, end_at = period

      Survey.find_by(start_at: start_at, end_at: end_at)
    end

    def initialize(now:)
      @now = now
    end

    def call
      period = self.class.current_period(now: now)
      raise NotCreationDayError, "サーベイを作成できるのは木曜日のみです" unless period

      start_at, end_at = period
      survey = Survey.find_or_initialize_by(start_at: start_at, end_at: end_at)

      survey.title = default_title(start_at) if survey.new_record?
      survey.status = :active unless survey.active?
      survey.save! if survey.new_record? || survey.changed?

      survey
    end

    private

    attr_reader :now

    def default_title(start_at)
      start_at.to_date.iso8601
    end
  end
end
