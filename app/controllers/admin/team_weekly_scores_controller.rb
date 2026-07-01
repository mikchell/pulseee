module Admin
  class TeamWeeklyScoresController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_score_viewer!

    UNKNOWN_GROUP_NAME = "未設定".freeze

    SurveyScore = Struct.new(:survey, :week_start_on, :week_end_on, :group_name,
                              :overall_average, :response_count, :question_averages,
                              keyword_init: true)

    def index
      scores = build_scores
      @weeks = scores.map(&:week_start_on).uniq.sort
      @latest_week = @weeks.last
      @previous_week = @weeks[-2]
      @group_names = scores.map(&:group_name).uniq.sort
      @question_labels = question_labels(scores)
      @question_descriptions = question_descriptions(scores)
      @scores_by_group = scores.group_by(&:group_name)
      @latest_scores = scores_for_week(scores, @latest_week)
      @previous_scores = scores_for_week(scores, @previous_week)
      @overall_points = overall_points(scores)
      @overall_latest_average = average(@latest_scores.map(&:overall_average))
      @overall_previous_average = average(@previous_scores.map(&:overall_average))
      @overall_delta = delta(@overall_latest_average, @overall_previous_average)
      @latest_response_count = @latest_scores.sum(&:response_count)
      @team_cards = team_cards
    end

    private

    def authorize_score_viewer!
      return if current_user&.score_viewer?

      redirect_to root_path, alert: "閲覧権限が必要です"
    end

    def build_scores
      completed_surveys.flat_map do |survey|
        rows_by_group(survey).filter_map do |group_name, rows|
          response_count = rows.map { |r| r[:submit_token] }.uniq.size
          next if response_count.zero?

          SurveyScore.new(
            survey: survey,
            week_start_on: survey.start_at.to_date,
            week_end_on: survey.end_at.to_date,
            group_name: group_name,
            overall_average: average(rows.map { |r| r[:score] }),
            response_count: response_count,
            question_averages: question_averages_for(rows)
          )
        end
      end
    end

    def completed_surveys
      Survey
        .active
        .where("end_at <= ?", Time.current)
        .where("exists (select 1 from survey_questions where survey_questions.survey_id = surveys.id)")
        .order(:start_at)
    end

    def rows_by_group(survey)
      ScoreAnswer
        .joins(survey_question: :survey)
        .joins("left join answer_group_snapshots on answer_group_snapshots.submit_token = score_answers.submit_token")
        .where(survey_questions: { survey_id: survey.id })
        .pluck(
          Arel.sql("coalesce(answer_group_snapshots.group_name, '#{UNKNOWN_GROUP_NAME}')"),
          "score_answers.submit_token",
          "survey_questions.order_index",
          "survey_questions.body",
          "score_answers.score"
        )
        .map { |group_name, submit_token, order_index, body, score|
          { group_name: group_name, submit_token: submit_token, order_index: order_index, body: body, score: score }
        }
        .group_by { |r| r[:group_name] }
    end

    def question_averages_for(rows)
      rows
        .group_by { |r| r[:order_index] }
        .sort_by { |order_index, _| order_index }
        .map { |order_index, qrows|
          [
            order_index.to_s,
            {
              "order_index" => qrows.first[:order_index],
              "body"        => qrows.first[:body],
              "average"     => average(qrows.map { |r| r[:score] })
            }
          ]
        }
        .to_h
    end

    def question_labels(scores)
      scores.each_with_object({}) do |score, labels|
        score.question_averages.each do |order_index, payload|
          labels[order_index] ||= "Q#{payload.fetch("order_index")}"
        end
      end
    end

    def scores_for_week(scores, week_start_on)
      return [] unless week_start_on

      scores.select { |s| s.week_start_on == week_start_on }
    end

    def overall_points(scores)
      @weeks.map do |week_start_on|
        week_scores = scores_for_week(scores, week_start_on)
        {
          label: score_date_label(week_start_on),
          value: average(week_scores.map(&:overall_average))
        }
      end
    end

    def team_cards
      @scores_by_group.map do |group_name, scores|
        latest = scores.max_by(&:week_start_on)
        previous = scores.sort_by(&:week_start_on)[-2]

        {
          group_name: group_name,
          latest: latest,
          delta: delta(latest&.overall_average, previous&.overall_average),
          points: scores.sort_by(&:week_start_on).map { |s|
            { label: score_date_label(s.week_start_on), value: s.overall_average }
          },
          question_averages: latest&.question_averages || {}
        }
      end.sort_by { |card| card.fetch(:group_name) }
    end

    def question_descriptions(scores)
      scores.each_with_object({}) do |score, descriptions|
        score.question_averages.each do |order_index, payload|
          descriptions[order_index] ||= {
            label: "Q#{payload.fetch("order_index")}",
            body: payload.fetch("body")
          }
        end
      end
    end

    def score_date_label(date)
      "#{date.month}/#{date.day}"
    end

    def average(values)
      values = values.compact
      return nil if values.empty?

      (values.sum.to_d / values.size).round(2)
    end

    def delta(current, previous)
      return nil unless current && previous

      (current.to_d - previous.to_d).round(2)
    end
  end
end
