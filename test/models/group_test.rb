require "test_helper"

class GroupTest < ActiveSupport::TestCase
  test "name is required" do
    assert_not Group.new.valid?
    assert Group.new(name: "開発").valid?
  end

  test "name must be unique" do
    Group.create!(name: "開発")
    duplicate = Group.new(name: "開発")

    assert_not duplicate.valid?
  end

  test "nullifies user group when group is destroyed" do
    group = Group.create!(name: "開発")
    user = User.create!(name: "テスト", email: "group-test@example.com", group: group)

    group.destroy
    assert_nil user.reload.group_id
  end
end
