module Surveys
  class UnansweredUsersQuery
    def self.call(survey:)
      new(survey: survey).call
    end

    def initialize(survey:)
      @survey = survey
    end

    def call
      User
        .joins(:survey_assignments)
        .where(survey_subject: true)
        .where(survey_assignments: { survey_id: survey.id, state: SurveyAssignment.states.fetch("pending") })
        .order(:name, :email)
    end

    private

    attr_reader :survey
  end
end
