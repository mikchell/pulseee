require Rails.root.join("lib/rails_admin/config/actions/download_survey_results")

RailsAdmin.config do |config|
  config.asset_source = :importmap
  config.parent_controller = "ApplicationController"

  config.authenticate_with do
    redirect_to main_app.root_path, alert: "ログインしてください" unless current_user
  end

  config.current_user_method(&:current_user)

  config.authorize_with do
    redirect_to main_app.root_path, alert: "管理者権限が必要です" unless current_user&.system_admin?
  end

  config.included_models = [
    "User",
    "Group",
    "Role",
    "Question",
    "Survey",
    "SurveyQuestion",
    "SurveyAssignment",
    "ScoreAnswer"
  ]

  config.actions do
    dashboard
    index
    show
    download_survey_results

    new do
      except %w[Role SurveyQuestion SurveyAssignment ScoreAnswer]
    end

    edit do
      except %w[Role SurveyQuestion SurveyAssignment ScoreAnswer]
    end

    delete do
      visible do
        object = (bindings || {})[:object]
        object.is_a?(Survey) && object.deletable?
      end
    end
  end

  config.model "User" do
    create do
      field :name
      field :email
      field :slack_user_id
      field :survey_subject
      field :group
      field :roles
    end

    edit do
      field :name
      field :slack_user_id
      field :survey_subject
      field :group
      field :roles
    end
  end

  config.model "Group" do
    create do
      field :name
    end

    edit do
      field :name
    end
  end

  config.model "Question" do
    create do
      field :body
    end

    edit do
      field :body
    end
  end

  config.model "Survey" do
    create do
      field :title
      field :status
      field :start_at
      field :end_at
    end

    edit do
      field :title
      field :status
      field :start_at
      field :end_at
      field :survey_questions
      field :survey_assignments
    end
  end

  %w[Role SurveyQuestion SurveyAssignment ScoreAnswer].each do |model_name|
    config.model model_name do
      visible false if model_name == "Role"
    end
  end
end
