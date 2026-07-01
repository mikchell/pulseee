class BackfillTeamWeeklyScores < ActiveRecord::Migration[8.1]
  def up
    Surveys::AggregateWeeklyTeamScores.call
  end

  def down
    TeamWeeklyScore.delete_all
  end
end
