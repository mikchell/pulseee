module Surveys
  class CreateCurrentWeekSurvey
    def self.call(now: Time.current)
      new(now: now).call
    end

    def self.current_period(now: Time.current)
      start_at = now.in_time_zone.to_date.next_occurring(:thursday).in_time_zone

      [ start_at, start_at + 2.days ]
    end

    def self.current_survey(now: Time.current)
      start_at, end_at = current_period(now: now)

      Survey.find_by(start_at: start_at, end_at: end_at)
    end

    def initialize(now:)
      @now = now
    end

    def call
      start_at, end_at = self.class.current_period(now: now)
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
