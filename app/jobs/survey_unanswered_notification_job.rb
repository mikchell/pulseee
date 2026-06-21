class SurveyUnansweredNotificationJob < ApplicationJob
  queue_as :default

  def perform(survey_id = nil)
    survey = survey_id.present? ? Survey.find(survey_id) : Survey.currently_active.order(:end_at).first
    return unless survey

    users = Surveys::UnansweredUsersQuery.call(survey: survey)
    return if users.empty?

    Slack::SurveyUnansweredNotifier.call(survey: survey, users: users)
  end
end
