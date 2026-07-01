module TeamWeeklyScoresHelper
  # ミニチャート（チームカード）用
  CHART_WIDTH = 640
  CHART_HEIGHT = 220
  CHART_PADDING_X = 28
  CHART_PADDING_Y = 18
  SCORE_MIN = BigDecimal("1.0")
  SCORE_MAX = BigDecimal("5.0")

  # 全体推移グラフ専用
  OVERALL_W           = 800
  OVERALL_H           = 300
  OVERALL_PAD_LEFT    = 52
  OVERALL_PAD_RIGHT   = 16
  OVERALL_PAD_TOP     = 18
  OVERALL_PAD_BOTTOM  = 48

  # チームカードミニチャート専用
  MINI_W        = 400
  MINI_H        = 130
  MINI_PAD_LEFT = 36
  MINI_PAD_RIGHT = 12
  MINI_PAD_Y    = 12

  # 全体グラフ: Y軸ラベル（1〜5）の座標一覧
  def overall_chart_y_axis
    [ 1, 2, 3, 4, 5 ].map { |s| { score: s, y: overall_y(s) } }
  end

  # 全体グラフ: データ点座標付きリスト
  def overall_chart_points(points)
    count = points.size
    points.each_with_index.map do |point, index|
      point.merge(x: overall_x(index, count), y: overall_y(point.fetch(:value)))
    end
  end

  # 全体グラフ: X軸ラベル（多すぎる場合は間引く）
  def overall_chart_x_labels(points, max_labels: 12)
    return [] if points.blank?

    step = [ (points.size.to_f / max_labels).ceil, 1 ].max
    points.each_with_index.filter_map do |point, index|
      next unless (index % step).zero? || index == points.size - 1

      { label: point.fetch(:label), x: overall_x(index, points.size) }
    end
  end

  # ミニチャート: Y軸ラベル（1・3・5のみ）
  def mini_chart_y_axis
    [ 1, 3, 5 ].map { |s| { score: s, y: mini_y(s) } }
  end

  # ミニチャート: 座標付きデータ点
  def mini_chart_points(points)
    count = points.size
    points.each_with_index.map do |point, index|
      point.merge(x: mini_x(index, count), y: mini_y(point.fetch(:value)))
    end
  end

  def score_chart_points(points, width: CHART_WIDTH, height: CHART_HEIGHT)
    return "" if points.blank?

    points.each_with_index.map do |point, index|
      x = chart_x(index, points.size, width)
      y = chart_y(point.fetch(:value), height)
      "#{x},#{y}"
    end.join(" ")
  end

  def score_chart_point_positions(points, width: CHART_WIDTH, height: CHART_HEIGHT)
    points.each_with_index.map do |point, index|
      point.merge(
        x: chart_x(index, points.size, width),
        y: chart_y(point.fetch(:value), height)
      )
    end
  end

  def score_percent(value)
    return 0 unless value

    value = value.to_d.clamp(SCORE_MIN, SCORE_MAX)
    (((value - SCORE_MIN) / (SCORE_MAX - SCORE_MIN)) * 100).round
  end

  def score_delta_class(delta)
    return "is-flat" if delta.blank? || delta.zero?

    delta.positive? ? "is-up" : "is-down"
  end

  def score_delta_text(delta)
    return "±0.00" if delta.blank? || delta.zero?

    "#{delta.positive? ? '+' : ''}#{number_with_precision(delta, precision: 2)}"
  end

  def score_date_label(date)
    "#{date.month}/#{date.day}"
  end

  private

  def mini_x(index, count)
    return MINI_W / 2 if count <= 1

    span = MINI_W - MINI_PAD_LEFT - MINI_PAD_RIGHT
    (MINI_PAD_LEFT + (span * index.to_f / (count - 1))).round(2)
  end

  def mini_y(value)
    value = value.to_d.clamp(SCORE_MIN, SCORE_MAX)
    span = MINI_H - (MINI_PAD_Y * 2)
    ratio = (value - SCORE_MIN) / (SCORE_MAX - SCORE_MIN)
    (MINI_H - MINI_PAD_Y - (span * ratio)).round(2)
  end

  def overall_x(index, count)
    return OVERALL_W / 2 if count <= 1

    span = OVERALL_W - OVERALL_PAD_LEFT - OVERALL_PAD_RIGHT
    (OVERALL_PAD_LEFT + (span * index.to_f / (count - 1))).round(2)
  end

  def overall_y(value)
    value = value.to_d.clamp(SCORE_MIN, SCORE_MAX)
    span = OVERALL_H - OVERALL_PAD_TOP - OVERALL_PAD_BOTTOM
    ratio = (value - SCORE_MIN) / (SCORE_MAX - SCORE_MIN)
    (OVERALL_H - OVERALL_PAD_BOTTOM - (span * ratio)).round(2)
  end

  def chart_x(index, count, width)
    return width / 2 if count == 1

    span = width - (CHART_PADDING_X * 2)
    (CHART_PADDING_X + (span * index.to_f / (count - 1))).round(2)
  end

  def chart_y(value, height)
    value = value.to_d.clamp(SCORE_MIN, SCORE_MAX)
    span = height - (CHART_PADDING_Y * 2)
    ratio = (value - SCORE_MIN) / (SCORE_MAX - SCORE_MIN)
    (height - CHART_PADDING_Y - (span * ratio)).round(2)
  end
end
