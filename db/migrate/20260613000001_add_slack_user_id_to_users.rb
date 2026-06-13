class AddSlackUserIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_user_id, :string
    add_index :users, :slack_user_id, unique: true, where: "slack_user_id is not null"
  end
end
