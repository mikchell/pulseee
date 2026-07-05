require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  test "standard ordered uses standard order instead of body" do
    create_standard_questions
    first = Question.find_by!(standard_order: 1)

    first.update!(body: "変更後の設問文")

    assert_equal [ 1, 2, 3, 4, 5 ], Question.standard_ordered.pluck(:standard_order)
    assert_equal "変更後の設問文", Question.standard_ordered.first.body
  end

  test "standard order must be unique" do
    create_standard_questions
    duplicate = Question.new(body: "重複順の設問", standard_order: 1)

    assert_not duplicate.valid?
  end
end
