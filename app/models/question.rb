class Question < ApplicationRecord
  STANDARD_BODIES = [
    "直近1週間に関して、あなたは自分がやりたいと思っている仕事ができていると思いますか？",
    "直近1週間に関して、あなたは良いパフォーマンス（行動や成果）を発揮できたと思いますか？",
    "直近1週間に関して、あなたは職場の人間関係が良好だったと思いますか？",
    "直近1週間に関して、あなたは十分な睡眠を取れていますか？",
    "直近1週間に関して、困ったことや壁にぶつかった際、上司に気兼ねなく相談・エスカレーションできる状態でしたか？"
  ].freeze

  has_many :survey_questions, dependent: :restrict_with_error

  before_destroy :prevent_destroy

  validates :body, presence: true
  validates :standard_order, presence: true, uniqueness: true,
                             numericality: { only_integer: true, greater_than: 0 }

  def self.standard_ordered
    order(:standard_order)
  end

  def self.standard_questions_ready?
    standard_ordered.size == STANDARD_BODIES.size
  end

  def self.ensure_standard_questions!
    STANDARD_BODIES.each.with_index(1) do |body, standard_order|
      question = find_or_initialize_by(standard_order: standard_order)
      question.body = body if question.new_record?
      question.save! if question.new_record? || question.changed?
    end
  end

  private

  def prevent_destroy
    errors.add(:base, "標準設問は削除できません")
    throw :abort
  end
end
