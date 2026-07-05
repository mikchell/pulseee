require "test_helper"

class ScoreAnswerTest < ActiveSupport::TestCase
  setup do
    create_standard_questions
    survey = Survey.create!(title: "スコア", start_at: 1.hour.ago, end_at: 1.hour.from_now)
    @survey_question = survey.survey_questions.first
  end

  test "score must be between one and five" do
    assert ScoreAnswer.new(submit_token: "token", survey_question: @survey_question, score: 1).valid?
    assert ScoreAnswer.new(submit_token: "token", survey_question: @survey_question, score: 5).valid?
    assert_not ScoreAnswer.new(submit_token: "token", survey_question: @survey_question, score: 0).valid?
    assert_not ScoreAnswer.new(submit_token: "token", survey_question: @survey_question, score: 6).valid?
  end

  test "submit token and survey question pair must be unique" do
    ScoreAnswer.create!(submit_token: "token", survey_question: @survey_question, score: 3)
    duplicate = ScoreAnswer.new(submit_token: "token", survey_question: @survey_question, score: 4)

    assert_not duplicate.valid?
  end

  test "score answers are append only" do
    answer = ScoreAnswer.create!(submit_token: "token", survey_question: @survey_question, score: 3)
    answer.score = 4

    assert_not answer.save
    assert_not answer.destroy
  end
end
