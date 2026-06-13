class SurveyCreationJob < ApplicationJob
  queue_as :default

  def perform
    Surveys::CreateCurrentWeekSurvey.call
  end
end
