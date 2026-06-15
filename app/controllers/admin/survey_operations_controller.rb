class Admin::SurveyOperationsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_system_admin!

  def show
    @current_week_survey = Surveys::CreateCurrentWeekSurvey.current_survey
    @current_active_survey = Survey.currently_active.order(:end_at).first
    @unanswered_count = @current_active_survey ? Surveys::UnansweredUsersQuery.call(survey: @current_active_survey).count : 0
    @slack_configured = Slack::SurveyUnansweredNotifier.configured?
  end

  def create_current_week_survey
    already_created = Surveys::CreateCurrentWeekSurvey.current_survey.present?

    SurveyCreationJob.perform_now

    notice = already_created ? "今週分サーベイはすでに作成済みです" : "今週分サーベイを作成しました"
    redirect_to admin_survey_operation_path, notice: notice
  rescue Surveys::CreateCurrentWeekSurvey::NotCreationDayError => error
    redirect_to admin_survey_operation_path, alert: error.message
  end

  def notify_unanswered_users
    survey = Survey.currently_active.order(:end_at).first
    unless survey
      redirect_to admin_survey_operation_path, alert: "通知対象の有効なサーベイがありません"
      return
    end

    unless Slack::SurveyUnansweredNotifier.configured?
      redirect_to admin_survey_operation_path, alert: "Slack通知用の環境変数を設定してください"
      return
    end

    SurveyUnansweredNotificationJob.perform_now(survey.id)

    redirect_to admin_survey_operation_path, notice: "未回答者のSlack通知を送信しました"
  end

  private

  def authorize_system_admin!
    return if current_user&.system_admin?

    redirect_to root_path, alert: "管理者権限が必要です"
  end
end
