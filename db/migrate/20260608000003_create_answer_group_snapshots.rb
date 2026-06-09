class CreateAnswerGroupSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :answer_group_snapshots do |t|
      t.string :submit_token, null: false
      t.string :group_name
      t.timestamps
    end

    add_index :answer_group_snapshots, :submit_token, unique: true
  end
end
