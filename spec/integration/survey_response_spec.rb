require "rails_helper"

RSpec.describe "SurveyResponseTest", type: :request do
  before do
    OmniAuth.config.test_mode = true
    create_standard_questions
  end

  after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  it "logged in user sees home" do
    user = User.create!(name: "利用者", email: "user@example.com")

    login_as(user)

    get root_path

    assert_response :success
    assert_select ".home-copy-line", text: "利用者さん"
  end

  it "pending user can answer active survey once" do
    travel_to Time.zone.local(2026, 6, 13, 12, 0) do
      user = User.create!(name: "対象者", email: "subject@example.com", survey_subject: true)
      survey = Survey.create!(
        title: "今週のサーベイ",
        status: :active,
        start_at: 1.hour.ago,
        end_at: Time.zone.local(2026, 6, 13, 13, 25)
      )
      assignment = survey.survey_assignments.find_by!(user: user)

      login_as(user)
      get root_path
      assert_select ".home-deadline-val", text: "2026/6/13 13:25"
      assert_select "a.home-pulse-link[href='#{new_survey_assignment_response_path(assignment)}']"
      get new_survey_assignment_response_path(assignment)
      assert_response :success
      assert_select ".question-progress-item", count: 5
      assert_select ".question-progress-item.is-answered", count: 0
      assert_select "input.score-choice-input[type=radio]", count: 25
      assert_select "input.score-choice-input[required]", count: 25
      assert_select ".score-choice", text: "そうだ", count: 5
      assert_select ".score-choice", text: "どちらとも言えない", count: 5
      assert_select ".score-choice", text: "ちがう", count: 5

      assert_difference -> { ScoreAnswer.count }, 5 do
        post survey_assignment_response_path(assignment), params: { answers: answers_for(survey, 4) }
      end
      follow_redirect!

      assert_select ".flash.notice", text: "回答を送信しました"
      assert_select ".home-meta-val", text: "回答が必要なサーベイはありません"

      assert_no_difference -> { ScoreAnswer.count } do
        post survey_assignment_response_path(assignment), params: { answers: answers_for(survey, 5) }
      end
      follow_redirect!
      assert_select ".flash.alert", text: "回答が必要なサーベイはありません"

      assert_no_difference -> { ScoreAnswer.count } do
        get new_survey_assignment_response_path(assignment)
      end
      follow_redirect!
      assert_select ".flash.alert", text: "回答が必要なサーベイはありません"
    end
  end

  it "expired and out of target surveys are not shown" do
    user = User.create!(name: "対象者", email: "hidden@example.com", survey_subject: true)
    expired = Survey.create!(title: "期限切れ", status: :active, start_at: 2.hours.ago, end_at: 1.hour.ago)
    assignment = expired.survey_assignments.find_by!(user: user)
    other = User.create!(name: "対象外", email: "outside@example.com", survey_subject: false)

    login_as(user)
    get root_path
    assert_select ".home-meta-val", text: "回答が必要なサーベイはありません"
    get new_survey_assignment_response_path(assignment)
    follow_redirect!
    assert_select ".flash.alert", text: "回答が必要なサーベイはありません"

    user.update!(survey_subject: false)
    Survey.create!(title: "対象外には出ない", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    login_as(other)
    get root_path
    assert_select ".home-meta-val", text: "回答が必要なサーベイはありません"
  end

  it "partial answers keep input and do not save" do
    user = User.create!(name: "対象者", email: "partial@example.com", survey_subject: true)
    survey = Survey.create!(title: "未回答チェック", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    assignment = survey.survey_assignments.find_by!(user: user)
    answers = answers_for(survey, 3)
    answers.delete(survey.survey_questions.first.id.to_s)

    login_as(user)

    assert_no_difference -> { ScoreAnswer.count } do
      post survey_assignment_response_path(assignment), params: { answers: answers }
    end

    assert_response :unprocessable_content
    assert_select ".flash.alert", text: "すべての設問に回答してください"
    assert_select ".question-progress-item.is-answered", count: 4
    assert_select "input.score-choice-input[checked='checked']", count: 4
    assert_select ".score-choice.is-selected", count: 4
  end

  it "missing answers are rejected without server error" do
    user = User.create!(name: "対象者", email: "missing@example.com", survey_subject: true)
    survey = Survey.create!(title: "未送信チェック", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    assignment = survey.survey_assignments.find_by!(user: user)

    login_as(user)

    assert_no_difference -> { ScoreAnswer.count } do
      post survey_assignment_response_path(assignment)
    end

    assert_response :unprocessable_content
    assert_select ".flash.alert", text: "すべての設問に回答してください"
  end

  it "unexpected answer keys are ignored" do
    user = User.create!(name: "対象者", email: "extra@example.com", survey_subject: true)
    survey = Survey.create!(title: "余計なキー", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    assignment = survey.survey_assignments.find_by!(user: user)
    answers = answers_for(survey, 4).merge("not_a_question" => "5", "999999" => "5")

    login_as(user)

    assert_difference -> { ScoreAnswer.count }, 5 do
      post survey_assignment_response_path(assignment), params: { answers: answers }
    end

    assert_redirected_to root_path
  end

  private

  def login_as(user)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "uid-#{user.email}",
      info: { email: user.email, name: user.name }
    )
    post "/auth/google_oauth2"
    follow_redirect! while response.redirect?
  end

  def answers_for(survey, score)
    survey.survey_questions.reload.index_with { score }.transform_keys { |question| question.id.to_s }
  end
end
