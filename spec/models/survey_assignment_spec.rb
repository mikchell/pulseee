require "rails_helper"

RSpec.describe "SurveyAssignment" do
  before do
    create_standard_questions
    @user = User.create!(name: "回答者", email: "respondent@example.com", survey_subject: true)
    @survey = Survey.create!(title: "回答テスト", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    @assignment = @survey.survey_assignments.find_by!(user: @user)
  end

  it "submits all scores anonymously" do
    assert_difference -> { ScoreAnswer.count }, 5 do
      assert @assignment.submit_scores!(answers_for(5))
    end

    assert @assignment.reload.submitted?
    assert_not_nil @assignment.submitted_at
    assert_equal 1, ScoreAnswer.distinct.count(:submit_token)
    assert_not_includes ScoreAnswer.column_names, "user_id"
    assert_not_includes ScoreAnswer.column_names, "survey_assignment_id"
    assert_not_includes ScoreAnswer.column_names, "created_at"
    assert_not_includes ScoreAnswer.column_names, "updated_at"
  end

  it "creates group snapshot on submit" do
    group = Group.create!(name: "開発")
    @user.update!(group: group)

    assert_difference -> { AnswerGroupSnapshot.count }, 1 do
      assert @assignment.submit_scores!(answers_for(4))
    end

    token = ScoreAnswer.last.submit_token
    snapshot = AnswerGroupSnapshot.find_by!(submit_token: token)
    assert_equal "開発", snapshot.group_name
  end

  it "creates group snapshot with nil group name when user has no group" do
    assert_difference -> { AnswerGroupSnapshot.count }, 1 do
      assert @assignment.submit_scores!(answers_for(3))
    end

    token = ScoreAnswer.last.submit_token
    snapshot = AnswerGroupSnapshot.find_by!(submit_token: token)
    assert_nil snapshot.group_name
  end

  it "does not save partial answers" do
    answers = answers_for(3)
    answers.delete(@survey.survey_questions.first.id)

    assert_no_difference -> { ScoreAnswer.count } do
      assert_not @assignment.submit_scores!(answers)
    end

    assert @assignment.reload.pending?
  end

  it "prevents duplicate assignments" do
    duplicate = SurveyAssignment.new(survey: @survey, user: @user)

    assert_not duplicate.valid?
  end

  it "submitted assignment cannot be reopened" do
    assert @assignment.submit_scores!(answers_for(4))

    @assignment.state = :pending

    assert_not @assignment.valid?
  end

  it "expired or submitted assignments are not answerable" do
    assert @assignment.answerable?

    @survey.update!(end_at: 1.minute.ago)

    assert_not @assignment.reload.answerable?
  end

  private

  def answers_for(score)
    @survey.survey_questions.index_with { score }.transform_keys(&:id)
  end
end
