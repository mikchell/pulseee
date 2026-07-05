require "test_helper"

class TeamWeeklyScoresTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    Question.ensure_standard_questions!
  end

  teardown do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  test "manager can view all team weekly scores" do
    manager = create_user_with_role("manager")
    create_survey_with_responses(group_name: "開発", scores: [ 5, 4, 4, 4, 4 ], week_start_on: Date.new(2026, 6, 8))
    create_survey_with_responses(group_name: "営業", scores: [ 4, 4, 3, 3, 3 ], week_start_on: Date.new(2026, 6, 8))

    login_as(manager)
    travel_to Time.zone.local(2026, 6, 20) do
      get admin_team_weekly_scores_path
    end

    assert_response :success
    assert_select "h1", text: "チーム別スコア推移"
    assert_select "h2", text: "開発"
    assert_select "h2", text: "営業"
    assert_select ".team-score-line-chart svg"
    assert_select ".team-score-mini-chart svg", minimum: 2
    assert_select ".team-score-question-fill"
    assert_select ".team-score-question-legend dt", text: "Q1"
    assert_select ".team-score-group-header span", text: "累計 1 件の回答"
    assert_select "td strong", text: "4.20"
    assert_select "td strong", text: "3.40"
    assert_select "#team-response-rate-heading", count: 0
    assert_no_match "回答率", response.body
  end

  test "system admin can view weekly response rates" do
    admin = create_user_with_role("system_admin")
    survey = create_survey_for_response_rate(week_start_on: Date.new(2026, 6, 8))
    submit_assignment(survey, "開発回答者")

    login_as(admin)
    travel_to Time.zone.local(2026, 6, 20) do
      get admin_team_weekly_scores_path
    end

    assert_response :success
    assert_select "#team-response-rate-heading", text: "週ごとの回答率"
    assert_select ".team-response-rate-table td strong", text: "33.3%"
    assert_select ".team-response-rate-table td", text: "1/3"
    assert_select ".team-response-rate-groups span", text: /開発\s+50.0%\s+1\/2/
    assert_select ".team-response-rate-groups span", text: /営業\s+0.0%\s+0\/1/
  end

  test "weekly score details are ordered newest first" do
    manager = create_user_with_role("manager")
    create_survey_with_responses(group_name: "開発", scores: [ 4, 4, 3, 3, 3 ], week_start_on: Date.new(2026, 6, 1))
    create_survey_with_responses(group_name: "開発", scores: [ 5, 4, 4, 4, 4 ], week_start_on: Date.new(2026, 6, 8))

    login_as(manager)
    travel_to Time.zone.local(2026, 6, 20) do
      get admin_team_weekly_scores_path
    end

    assert_response :success
    assert_match(%r{6/8.*6/1}m, response.body)
  end

  test "system admin can navigate from home" do
    admin = create_user_with_role("system_admin")
    login_as(admin)

    get root_path

    assert_response :success
    assert_select "a[href='#{admin_team_weekly_scores_path}']", text: "チームスコア"
  end

  test "member cannot view team weekly scores" do
    member = User.create!(name: "一般", email: "member-score@example.com")
    login_as(member)

    get admin_team_weekly_scores_path
    follow_redirect!

    assert_select ".flash.alert", text: "閲覧権限が必要です"
  end

  private

  def create_user_with_role(role_name)
    role = Role.find_or_create_by!(name: role_name)
    User.create!(name: role_name, email: "#{role_name}@example.com").tap do |user|
      user.roles << role
    end
  end

  def create_survey_with_responses(group_name:, scores:, week_start_on:)
    group = Group.find_or_create_by!(name: group_name)
    user = User.find_or_create_by!(email: "#{group_name}-respondent@example.com") do |u|
      u.name = "#{group_name}回答者"
      u.survey_subject = true
      u.group = group
    end

    end_date = (week_start_on + 4.days).in_time_zone
    survey = Survey.create!(
      title: "#{group_name}サーベイ #{week_start_on}",
      status: :active,
      start_at: week_start_on.in_time_zone,
      end_at: end_date
    )

    travel_to end_date - 1.hour do
      answers = survey.survey_questions.ordered.zip(scores).to_h { |sq, score| [ sq.id, score ] }
      survey.survey_assignments.find_by!(user: user).submit_scores!(answers)
    end
  end

  def create_survey_for_response_rate(week_start_on:)
    development = Group.find_or_create_by!(name: "開発")
    sales = Group.find_or_create_by!(name: "営業")

    [
      [ "開発回答者", "dev-submitted@example.com", development ],
      [ "開発未回答", "dev-pending@example.com", development ],
      [ "営業未回答", "sales-pending@example.com", sales ]
    ].each do |name, email, group|
      User.create!(name: name, email: email, survey_subject: true, group: group)
    end

    Survey.create!(
      title: "回答率テスト #{week_start_on}",
      status: :active,
      start_at: week_start_on.in_time_zone,
      end_at: (week_start_on + 4.days).in_time_zone
    )
  end

  def submit_assignment(survey, user_name)
    assignment = survey.survey_assignments.joins(:user).find_by!(users: { name: user_name })
    answers = survey.survey_questions.ordered.index_with { 4 }.transform_keys(&:id)

    travel_to survey.end_at - 1.hour do
      assert assignment.submit_scores!(answers)
    end
  end

  def login_as(user)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "uid-#{user.email}",
      info: { email: user.email, name: user.name }
    )
    post "/auth/google_oauth2"
    follow_redirect! while response.redirect?
  end
end
