class User < ApplicationRecord
  belongs_to :group, optional: true
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :survey_assignments, dependent: :restrict_with_error

  before_validation :normalize_email
  before_validation :normalize_slack_user_id
  after_save :create_assignments_for_currently_active_surveys, if: :survey_subject?
  before_destroy :prevent_destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :slack_user_id, uniqueness: { allow_nil: true }

  def system_admin?
    roles.exists?(name: "system_admin")
  end

  def next_pending_survey_assignment
    survey_assignments.answerable.first
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def normalize_slack_user_id
    self.slack_user_id = slack_user_id.to_s.strip.presence
  end

  def create_assignments_for_currently_active_surveys
    Survey.currently_active.find_each do |survey|
      survey.survey_assignments.find_or_create_by!(user: self) do |assignment|
        assignment.state = :pending
      end
    end
  end

  def prevent_destroy
    errors.add(:base, "ユーザーは削除できません")
    throw :abort
  end
end
