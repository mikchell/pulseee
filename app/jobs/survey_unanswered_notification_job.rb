class SurveyUnansweredNotificationJob < ApplicationJob
  queue_as :default

  def perform(survey_id = nil)
    survey = survey_id.present? ? Survey.find(survey_id) : Surveys::CreateCurrentWeekSurvey.call
    users = Surveys::UnansweredUsersQuery.call(survey: survey)

    Slack::SurveyUnansweredNotifier.call(survey: survey, users: users)
  end
end
