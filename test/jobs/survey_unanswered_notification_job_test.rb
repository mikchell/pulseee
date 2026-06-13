require "test_helper"

class SurveyUnansweredNotificationJobTest < ActiveJob::TestCase
  setup do
    Question.ensure_standard_questions!
  end

  test "notifies unanswered users for specified survey" do
    answered = User.create!(name: "回答済み", email: "answered@example.com", survey_subject: true)
    pending = User.create!(name: "未回答", email: "pending@example.com", survey_subject: true)
    survey = Survey.create!(title: "通知対象", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    survey.survey_assignments.find_by!(user: answered).submit_scores!(answers_for(survey, 4))
    notified = []
    original_call = Slack::SurveyUnansweredNotifier.method(:call)

    Slack::SurveyUnansweredNotifier.define_singleton_method(:call) do |survey:, users:|
      notified << [ survey, users.to_a ]
    end

    begin
      SurveyUnansweredNotificationJob.perform_now(survey.id)
    ensure
      Slack::SurveyUnansweredNotifier.define_singleton_method(:call, original_call)
    end

    assert_equal [ [ survey, [ pending ] ] ], notified
  end

  private

  def answers_for(survey, score)
    survey.survey_questions.index_with { score }.transform_keys(&:id)
  end
end
