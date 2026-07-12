require "rails_helper"

RSpec.describe "SurveyCreationJob", type: :job do
  it "creates current week survey" do
    travel_to Time.zone.local(2026, 6, 11, 12, 0) do
      assert_difference -> { Survey.count }, 1 do
        SurveyCreationJob.perform_now
      end
    end
  end

  it "does not create current week survey outside Thursday" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0) do
      assert_no_difference -> { Survey.count } do
        assert_raises(Surveys::CreateCurrentWeekSurvey::NotCreationDayError) do
          SurveyCreationJob.perform_now
        end
      end
    end
  end
end
