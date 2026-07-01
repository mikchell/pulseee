require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    create_standard_questions
  end

  test "email is normalized and unique" do
    User.create!(name: "利用者", email: "USER@example.com", survey_subject: true)
    duplicate = User.new(name: "重複", email: " user@example.com ", survey_subject: true)

    assert_not duplicate.valid?
    assert_equal "user@example.com", duplicate.email
  end

  test "slack user id is normalized and unique when present" do
    user = User.create!(name: "Slack利用者", email: "slack@example.com", slack_user_id: " U12345678 ")

    duplicate = User.new(name: "重複", email: "duplicate@example.com", slack_user_id: "U12345678")
    blank = User.new(name: "空欄", email: "blank@example.com", slack_user_id: " ")

    assert_equal "U12345678", user.slack_user_id
    assert_not duplicate.valid?
    assert blank.valid?
    assert_nil blank.slack_user_id
  end

  test "system admin role check" do
    role = Role.create!(name: "system_admin")
    user = User.create!(name: "管理者", email: "admin@example.com")

    assert_not user.system_admin?

    user.roles << role

    assert user.system_admin?
  end

  test "manager can view scores" do
    role = Role.create!(name: "manager")
    user = User.create!(name: "マネージャー", email: "manager@example.com")

    assert_not user.manager?
    assert_not user.score_viewer?

    user.roles << role

    assert user.manager?
    assert user.score_viewer?
  end

  test "survey subject receives assignments for currently active surveys" do
    user = User.create!(name: "対象者", email: "subject@example.com", survey_subject: false)
    active = Survey.create!(title: "実施中", status: :active, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    draft = Survey.create!(title: "下書き", status: :draft, start_at: 1.hour.ago, end_at: 1.hour.from_now)
    expired = Survey.create!(title: "期限切れ", status: :active, start_at: 2.hours.ago, end_at: 1.hour.ago)

    assert_empty user.survey_assignments

    user.update!(survey_subject: true)

    assert_equal [ active.id ], user.survey_assignments.pluck(:survey_id)
    assert_equal "pending", user.survey_assignments.first.state
    assert_not_includes user.survey_assignments.pluck(:survey_id), draft.id
    assert_not_includes user.survey_assignments.pluck(:survey_id), expired.id
  end

  private

  def create_standard_questions
    Question::STANDARD_BODIES.each { |body| Question.find_or_create_by!(body: body) }
  end
end
