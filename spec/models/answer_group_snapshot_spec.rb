require "rails_helper"

RSpec.describe "AnswerGroupSnapshot" do
  it "submit_token is required" do
    assert_not AnswerGroupSnapshot.new(group_name: "開発").valid?
    assert AnswerGroupSnapshot.new(submit_token: "abc", group_name: "開発").valid?
  end

  it "submit_token must be unique" do
    AnswerGroupSnapshot.create!(submit_token: "token-1", group_name: "開発")
    duplicate = AnswerGroupSnapshot.new(submit_token: "token-1", group_name: "メンサポ")

    assert_not duplicate.valid?
  end

  it "group_name can be nil" do
    assert AnswerGroupSnapshot.new(submit_token: "token-2").valid?
  end

  it "snapshots are append only" do
    snapshot = AnswerGroupSnapshot.create!(submit_token: "token-3", group_name: "開発")
    snapshot.group_name = "メンサポ"

    assert_not snapshot.save
    assert_not snapshot.destroy
  end
end
