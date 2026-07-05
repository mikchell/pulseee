module Surveys
  class WeeklyResponseRatesQuery
    UNKNOWN_GROUP_NAME = "未設定".freeze
    DEFAULT_LIMIT = 8

    GroupRate = Struct.new(:group_name, :assigned_count, :submitted_count, :rate, keyword_init: true)
    WeekRate = Struct.new(:survey, :week_start_on, :week_end_on, :assigned_count,
                          :submitted_count, :rate, :group_rates, keyword_init: true)

    def self.call(limit: DEFAULT_LIMIT)
      new(limit: limit).call
    end

    def initialize(limit:)
      @limit = limit
    end

    def call
      surveys.map do |survey|
        assignments = survey.survey_assignments.includes(user: :group).to_a

        WeekRate.new(
          survey: survey,
          week_start_on: survey.start_at.to_date,
          week_end_on: survey.end_at.to_date,
          assigned_count: assignments.size,
          submitted_count: submitted_count(assignments),
          rate: rate(assignments),
          group_rates: group_rates(assignments)
        )
      end
    end

    private

    attr_reader :limit

    def surveys
      Survey
        .active
        .includes(:survey_assignments)
        .order(start_at: :desc)
        .limit(limit)
    end

    def group_rates(assignments)
      assignments
        .group_by { |assignment| assignment.user.group&.name || UNKNOWN_GROUP_NAME }
        .map { |group_name, group_assignments|
          GroupRate.new(
            group_name: group_name,
            assigned_count: group_assignments.size,
            submitted_count: submitted_count(group_assignments),
            rate: rate(group_assignments)
          )
        }
        .sort_by(&:group_name)
    end

    def submitted_count(assignments)
      assignments.count(&:submitted?)
    end

    def rate(assignments)
      return nil if assignments.empty?

      ((submitted_count(assignments).to_d / assignments.size) * 100).round(1)
    end
  end
end
