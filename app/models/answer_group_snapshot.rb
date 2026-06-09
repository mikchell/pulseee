class AnswerGroupSnapshot < ApplicationRecord
  validates :submit_token, presence: true, uniqueness: true

  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def prevent_mutation
    errors.add(:base, "スナップショットは変更できません")
    throw :abort
  end
end
