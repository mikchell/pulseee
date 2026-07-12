require "rails_helper"

RSpec.describe "SurveyUnansweredNotificationJob", type: :job do
  before do
    Question.ensure_standard_questions!
  end

  it "notifies unanswered users for specified survey" do
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

  it "notifies unanswered users for current active survey without specified survey" do
    pending = User.create!(name: "未回答", email: "pending-current@example.com", survey_subject: true)
    survey = Survey.create!(title: "現在有効", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assert_notifier_called_with([ [ survey, [ pending ] ] ]) do
      SurveyUnansweredNotificationJob.perform_now
    end
  end

  it "does not notify when all users have answered" do
    answered = User.create!(name: "回答済み", email: "all-answered@example.com", survey_subject: true)
    survey = Survey.create!(title: "全員回答済み", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    survey.survey_assignments.find_by!(user: answered).submit_scores!(answers_for(survey, 4))

    assert_notifier_called_with([]) do
      SurveyUnansweredNotificationJob.perform_now
    end
  end

  it "does nothing without current active survey" do
    Survey.create!(title: "終了済み", status: :active, start_at: 3.days.ago, end_at: 2.days.ago)

    assert_notifier_called_with([]) do
      SurveyUnansweredNotificationJob.perform_now
    end
  end

  private

  def assert_notifier_called_with(expected)
    notified = []
    original_call = Slack::SurveyUnansweredNotifier.method(:call)

    Slack::SurveyUnansweredNotifier.define_singleton_method(:call) do |survey:, users:|
      notified << [ survey, users.to_a ]
    end

    yield
  ensure
    Slack::SurveyUnansweredNotifier.define_singleton_method(:call, original_call)
    assert_equal expected, notified
  end

  def answers_for(survey, score)
    survey.survey_questions.index_with { score }.transform_keys(&:id)
  end
end
