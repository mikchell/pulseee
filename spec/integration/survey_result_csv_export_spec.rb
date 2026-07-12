require "rails_helper"
require "csv"

RSpec.describe "SurveyResultCsvExportTest", type: :request do
  before do
    OmniAuth.config.test_mode = true
    @system_admin_role = Role.create!(name: "system_admin")
    @admin = User.create!(name: "管理者", email: "csv-admin@example.com")
    @admin.roles << @system_admin_role
    @member = User.create!(name: "一般", email: "csv-member@example.com")
  end

  after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  it "system admin can export anonymous survey results as csv" do
    survey = create_answered_survey

    login_as(@admin)
    get admin_survey_results_path(survey, format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.headers["Content-Disposition"], "survey-#{survey.id}-results.csv"
    assert response.body.start_with?(SurveyResultCsvExporter::UTF_8_BOM)

    csv = CSV.parse(response.body.delete_prefix(SurveyResultCsvExporter::UTF_8_BOM), headers: true)
    first_row = csv.first
    score_rows = csv.map { |row| [ row["Q1"], row["Q2"], row["Q3"], row["Q4"], row["Q5"] ] }.sort

    assert_equal 3, csv.size
    assert_equal [ "サーベイID", "サーベイ名", "グループ", "Q1", "Q2", "Q3", "Q4", "Q5" ], csv.headers
    assert_not_includes csv.headers, "submit_token"
    assert_not_includes csv.headers, "ユーザーID"
    assert_not_includes csv.headers, "匿名回答ID"
    assert_not_includes csv.headers, "対象者数"
    assert_not_includes csv.headers, "回答済み数"
    assert_not_includes csv.headers, "回答率"
    assert_equal [
      [ "1", "1", "1", "1", "1" ],
      [ "3", "3", "3", "3", "3" ],
      [ "5", "5", "5", "5", "5" ]
    ], score_rows
    assert_equal survey.id.to_s, first_row["サーベイID"]
    assert_equal "集計テスト", first_row["サーベイ名"]
  end

  it "system admin sees csv download action on survey detail" do
    survey = create_answered_survey

    login_as(@admin)
    get "/admin/survey/#{survey.id}"

    assert_response :success
    assert_select "a", text: /CSVダウンロード/
    assert_includes response.body, "/admin/survey/#{survey.id}/download_survey_results"

    get "/admin/survey/#{survey.id}/download_survey_results"
    assert_response :success
    assert_equal "text/csv", response.media_type
  end

  it "csv includes group name snapshot at time of submission" do
    group = Group.create!(name: "開発")
    create_standard_questions
    user = User.create!(name: "開発者", email: "csv-dev@example.com", survey_subject: true, group: group)
    survey = Survey.create!(title: "グループテスト", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    assignment = survey.survey_assignments.find_by!(user: user)
    answers = survey.survey_questions.index_with { 3 }.transform_keys(&:id)
    assignment.submit_scores!(answers)

    # グループ変更後も過去の回答は元のグループ名を保持する
    user.update!(group: nil)

    login_as(@admin)
    get admin_survey_results_path(survey, format: :csv)

    csv = CSV.parse(response.body.delete_prefix(SurveyResultCsvExporter::UTF_8_BOM), headers: true)
    assert_equal "開発", csv.first["グループ"]
  end

  it "survey result csv export requires system admin" do
    survey = create_answered_survey

    get admin_survey_results_path(survey, format: :csv)
    follow_redirect!
    assert_select ".flash.alert", text: "ログインしてください"

    login_as(@member)
    get admin_survey_results_path(survey, format: :csv)
    follow_redirect!
    assert_select ".flash.alert", text: "管理者権限が必要です"
  end

  private

  def create_answered_survey
    create_standard_questions
    users = 3.times.map do |index|
      User.create!(
        name: "対象者#{index + 1}",
        email: "csv-subject-#{index + 1}@example.com",
        survey_subject: true
      )
    end

    survey = Survey.create!(
      title: "集計テスト",
      status: :active,
      start_at: 1.hour.ago,
      end_at: 1.hour.from_now
    )

    users.zip([ 1, 3, 5 ]).each do |user, score|
      assignment = survey.survey_assignments.find_by!(user: user)
      answers = survey.survey_questions.index_with { score }.transform_keys(&:id)

      assert assignment.submit_scores!(answers)
    end

    survey
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
