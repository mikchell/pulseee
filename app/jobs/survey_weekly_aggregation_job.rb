class SurveyWeeklyAggregationJob < ApplicationJob
  queue_as :default

  def perform
    survey = Survey.active.where("end_at <= ?", Time.current).order(end_at: :desc).first
    return unless survey

    SurveyResultCsvExporter.new(survey).generate
  end
end
