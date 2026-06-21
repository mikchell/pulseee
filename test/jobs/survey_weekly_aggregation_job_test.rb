require "test_helper"

class SurveyWeeklyAggregationJobTest < ActiveJob::TestCase
  setup do
    Question.ensure_standard_questions!
  end

  test "generates results for the latest ended active survey" do
    older = Survey.create!(
      title: "古いサーベイ",
      status: :active,
      start_at: Time.zone.local(2026, 6, 4, 0, 0),
      end_at: Time.zone.local(2026, 6, 6, 0, 0)
    )
    latest = Survey.create!(
      title: "直近のサーベイ",
      status: :active,
      start_at: Time.zone.local(2026, 6, 11, 0, 0),
      end_at: Time.zone.local(2026, 6, 13, 0, 0)
    )
    Survey.create!(
      title: "実施中のサーベイ",
      status: :active,
      start_at: Time.zone.local(2026, 6, 18, 0, 0),
      end_at: Time.zone.local(2026, 6, 20, 0, 0)
    )
    generated_for = []
    original_new = SurveyResultCsvExporter.method(:new)

    SurveyResultCsvExporter.define_singleton_method(:new) do |survey|
      generated_for << survey
      original_new.call(survey)
    end

    travel_to Time.zone.local(2026, 6, 15, 9, 0) do
      SurveyWeeklyAggregationJob.perform_now
    end

    assert_equal [ latest ], generated_for
    assert_not_includes generated_for, older
  ensure
    SurveyResultCsvExporter.define_singleton_method(:new, original_new) if original_new
  end

  test "does nothing when no ended active survey exists" do
    Survey.create!(
      title: "実施中のサーベイ",
      status: :active,
      start_at: Time.zone.local(2026, 6, 11, 0, 0),
      end_at: Time.zone.local(2026, 6, 13, 0, 0)
    )
    generated_for = []
    original_new = SurveyResultCsvExporter.method(:new)

    SurveyResultCsvExporter.define_singleton_method(:new) do |survey|
      generated_for << survey
      original_new.call(survey)
    end

    travel_to Time.zone.local(2026, 6, 12, 9, 0) do
      SurveyWeeklyAggregationJob.perform_now
    end

    assert_empty generated_for
  ensure
    SurveyResultCsvExporter.define_singleton_method(:new, original_new) if original_new
  end
end
