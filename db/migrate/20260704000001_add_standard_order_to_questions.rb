class AddStandardOrderToQuestions < ActiveRecord::Migration[8.1]
  STANDARD_BODIES = [
    "直近1週間に関して、あなたは自分がやりたいと思っている仕事ができていると思いますか？",
    "直近1週間に関して、あなたは良いパフォーマンス（行動や成果）を発揮できたと思いますか？",
    "直近1週間に関して、あなたは職場の人間関係が良好だったと思いますか？",
    "直近1週間に関して、あなたは十分な睡眠を取れていますか？",
    "直近1週間に関して、困ったことや壁にぶつかった際、上司に気兼ねなく相談・エスカレーションできる状態でしたか？"
  ].freeze

  def up
    add_column :questions, :standard_order, :integer

    STANDARD_BODIES.each.with_index(1) do |body, standard_order|
      execute <<~SQL.squish
        update questions
        set standard_order = #{standard_order}
        where body = #{connection.quote(body)}
      SQL
    end

    execute <<~SQL.squish
      with available_orders as (
        select generate_series(1, (select count(*) from questions)) as standard_order
        except
        select standard_order from questions where standard_order is not null
      ),
      unordered_questions as (
        select id, row_number() over (order by id) as row_number
        from questions
        where standard_order is null
      ),
      numbered_orders as (
        select standard_order, row_number() over (order by standard_order) as row_number
        from available_orders
      )
      update questions
      set standard_order = numbered_orders.standard_order
      from unordered_questions, numbered_orders
      where questions.id = unordered_questions.id
        and unordered_questions.row_number = numbered_orders.row_number
    SQL

    change_column_null :questions, :standard_order, false
    add_index :questions, :standard_order, unique: true
  end

  def down
    remove_index :questions, :standard_order
    remove_column :questions, :standard_order
  end
end
