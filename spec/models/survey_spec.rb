require "rails_helper"

RSpec.describe "Survey" do
  before do
    create_standard_questions
  end

  it "currently active surveys must be active and within period" do
    active = Survey.create!(title: "有効", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    draft = Survey.create!(title: "下書き", status: :draft, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    expired = Survey.create!(title: "期限切れ", status: :active, start_at: 2.hours.ago, end_at: 1.hour.ago)

    assert active.currently_active?
    assert_includes Survey.currently_active, active
    assert_not draft.currently_active?
    assert_not_includes Survey.currently_active, draft
    assert_not expired.currently_active?
    assert_not_includes Survey.currently_active, expired
  end

  it "copies standard questions at creation time" do
    survey = Survey.create!(title: "コピー", start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assert_equal 5, survey.survey_questions.count
    assert_equal Question::STANDARD_BODIES, survey.survey_questions.order(:order_index).pluck(:body)

    Question.first.update!(body: "変更後")

    assert_not_equal "変更後", survey.survey_questions.order(:order_index).first.body
  end

  it "creates standard questions when missing" do
    Question.delete_all

    survey = Survey.create!(title: "設問なし", start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assert_equal 5, Question.count
    assert_equal Question::STANDARD_BODIES, survey.survey_questions.order(:order_index).pluck(:body)
  end

  it "activating survey creates fixed assignments once" do
    subject = User.create!(name: "対象者", email: "subject@example.com", survey_subject: true)
    other = User.create!(name: "対象外", email: "other@example.com", survey_subject: false)
    survey = Survey.create!(title: "固定", status: :draft, start_at: 1.hour.ago, end_at: 1.hour.from_now)

    survey.update!(status: :active)

    assert_equal [ subject.id ], survey.survey_assignments.pluck(:user_id)
    assert_equal "pending", survey.survey_assignments.first.state

    subject.update!(survey_subject: false)
    other.update!(survey_subject: true)
    survey.update!(status: :draft)
    survey.update!(status: :active)

    assert_equal [ subject.id, other.id ].sort, survey.survey_assignments.reload.pluck(:user_id).sort
    assert_not subject.next_pending_survey_assignment
    assert_equal survey.survey_assignments.find_by(user: other), other.next_pending_survey_assignment
  end

  it "only unanswered draft surveys can be deleted" do
    survey = Survey.create!(title: "削除可", status: :draft, start_at: 1.hour.ago, end_at: 1.hour.from_now)

    assert survey.destroy

    user = User.create!(name: "回答者", email: "answerer@example.com", survey_subject: true)
    answered = Survey.create!(title: "回答あり", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    assignment = answered.survey_assignments.find_by!(user: user)
    assignment.submit_scores!(answers_for(answered, 4))
    answered.update!(status: :draft)

    assert_not answered.destroy
  end

  private

  def answers_for(survey, score)
    survey.survey_questions.index_with { score }.transform_keys(&:id)
  end
end
