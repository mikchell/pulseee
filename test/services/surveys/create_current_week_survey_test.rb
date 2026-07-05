require "test_helper"

class Surveys::CreateCurrentWeekSurveyTest < ActiveSupport::TestCase
  test "creates active current week survey once" do
    user = User.create!(name: "対象者", email: "subject@example.com", survey_subject: true)

    travel_to Time.zone.local(2026, 6, 11, 12, 0) do
      assert_difference -> { Survey.count }, 1 do
        @survey = Surveys::CreateCurrentWeekSurvey.call
      end

      assert @survey.active?
      assert_equal "2026-06-11", @survey.title
      assert_equal Time.zone.local(2026, 6, 11, 0, 0), @survey.start_at
      assert_equal Time.zone.local(2026, 6, 14, 0, 0), @survey.end_at
      assert_equal [ user.id ], @survey.survey_assignments.pluck(:user_id)

      assert_no_difference -> { Survey.count } do
        assert_equal @survey, Surveys::CreateCurrentWeekSurvey.call
      end
    end
  end

  test "does not create survey on Wednesday" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0) do
      assert_nil Surveys::CreateCurrentWeekSurvey.current_period
      assert_nil Surveys::CreateCurrentWeekSurvey.current_survey

      assert_no_difference -> { Survey.count } do
        assert_raises(Surveys::CreateCurrentWeekSurvey::NotCreationDayError) do
          Surveys::CreateCurrentWeekSurvey.call
        end
      end
    end
  end

  test "does not create survey on Friday" do
    travel_to Time.zone.local(2026, 6, 12, 12, 0) do
      assert_nil Surveys::CreateCurrentWeekSurvey.current_period
      assert_nil Surveys::CreateCurrentWeekSurvey.current_survey

      assert_no_difference -> { Survey.count } do
        assert_raises(Surveys::CreateCurrentWeekSurvey::NotCreationDayError) do
          Surveys::CreateCurrentWeekSurvey.call
        end
      end
    end
  end

  test "activates existing current week draft" do
    travel_to Time.zone.local(2026, 6, 11, 12, 0) do
      start_at, end_at = Surveys::CreateCurrentWeekSurvey.current_period
      draft = Survey.create!(title: "既存下書き", status: :draft, start_at: start_at, end_at: end_at)

      survey = Surveys::CreateCurrentWeekSurvey.call

      assert_equal draft, survey
      assert survey.active?
      assert_equal "既存下書き", survey.title
    end
  end
end
