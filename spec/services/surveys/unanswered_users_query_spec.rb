require "rails_helper"

RSpec.describe "Surveys::UnansweredUsersQuery" do
  before do
    Question.ensure_standard_questions!
  end

  it "returns pending survey subjects ordered by name and email" do
    answered = User.create!(name: "回答済み", email: "answered@example.com", survey_subject: true)
    second = User.create!(name: "未回答B", email: "second@example.com", survey_subject: true)
    first = User.create!(name: "未回答A", email: "first@example.com", survey_subject: true)
    User.create!(name: "対象外", email: "outside@example.com", survey_subject: false)
    survey = Survey.create!(title: "今週", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assignment = survey.survey_assignments.find_by!(user: answered)
    assert assignment.submit_scores!(answers_for(survey, 4))

    users = Surveys::UnansweredUsersQuery.call(survey: survey)

    assert_equal [ first, second ], users.to_a
  end

  private

  def answers_for(survey, score)
    survey.survey_questions.index_with { score }.transform_keys(&:id)
  end
end
