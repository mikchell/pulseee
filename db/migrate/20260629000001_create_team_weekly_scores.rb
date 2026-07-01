class CreateTeamWeeklyScores < ActiveRecord::Migration[8.1]
  def change
    create_table :team_weekly_scores do |t|
      t.references :survey, null: false, foreign_key: true
      t.date :week_start_on, null: false
      t.date :week_end_on, null: false
      t.string :group_name, null: false
      t.decimal :overall_average, precision: 4, scale: 2, null: false
      t.integer :response_count, null: false
      t.jsonb :question_averages, null: false, default: {}

      t.timestamps
    end

    add_index :team_weekly_scores, [ :survey_id, :group_name ], unique: true
    add_index :team_weekly_scores, [ :week_start_on, :group_name ]
  end
end
