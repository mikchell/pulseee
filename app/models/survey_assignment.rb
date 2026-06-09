class SurveyAssignment < ApplicationRecord
  enum :state, { pending: "pending", submitted: "submitted" }, validate: true

  belongs_to :survey
  belongs_to :user

  validates :user_id, uniqueness: { scope: :survey_id }
  validate :submitted_assignments_cannot_be_reopened, on: :update

  scope :answerable, -> {
    pending
      .joins(:survey, :user)
      .merge(Survey.currently_active)
      .where(users: { survey_subject: true })
      .where("exists (select 1 from survey_questions where survey_questions.survey_id = survey_assignments.survey_id)")
      .order("surveys.end_at asc")
  }

  def answerable?
    pending? && user.survey_subject? && survey.currently_active? && survey.survey_questions.exists?
  end

  def submit_scores!(score_params)
    errors.clear

    questions = survey.survey_questions.ordered.to_a
    scores = scores_for(questions, score_params)
    return false if errors.any?

    with_lock do
      reload
      unless answerable?
        errors.add(:base, "回答が必要なサーベイはありません")
        return false
      end

      submit_token = SecureRandom.uuid
      questions.each do |question|
        ScoreAnswer.create!(
          submit_token: submit_token,
          survey_question: question,
          score: scores.fetch(question.id)
        )
      end
      AnswerGroupSnapshot.create!(
        submit_token: submit_token,
        group_name: user.group&.name
      )
      update!(state: :submitted, submitted_at: Time.current)
    end

    true
  rescue ActiveRecord::RecordInvalid
    errors.add(:base, "すべての設問に回答してください")
    false
  end

  private

  def scores_for(questions, score_params)
    if questions.empty?
      errors.add(:base, "回答が必要なサーベイはありません")
      return {}
    end

    questions.each_with_object({}) do |question, scores|
      raw_score = score_params[question.id.to_s] || score_params[question.id]
      score = Integer(raw_score, exception: false)
      if score.blank? || !score.between?(ScoreAnswer::MIN_SCORE, ScoreAnswer::MAX_SCORE)
        errors.add(:base, "すべての設問に回答してください")
        next
      end

      scores[question.id] = score
    end
  end

  def submitted_assignments_cannot_be_reopened
    return unless state_change_to_be_saved == [ "submitted", "pending" ]

    errors.add(:state, "を未回答に戻すことはできません")
  end
end
