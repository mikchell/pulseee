class AddGroupToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :group, null: true, foreign_key: true
  end
end
