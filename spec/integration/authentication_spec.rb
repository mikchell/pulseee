require "rails_helper"

RSpec.describe "AuthenticationTest", type: :request do
  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  it "registered user can login with google auth mock" do
    User.create!(name: "登録済み", email: "registered@example.com")
    mock_google_auth("registered@example.com")

    post "/auth/google_oauth2"
    follow_all_redirects

    assert_response :success
    assert_select ".flash.notice", text: "ログインしました"
    assert_select ".flash.notice[data-controller='flash']"
  end

  it "unregistered google auth user cannot login" do
    mock_google_auth("unknown@example.com")

    post "/auth/google_oauth2"
    follow_redirect!
    assert_redirected_to login_path
    follow_all_redirects

    assert_response :success
    assert_select ".flash.alert", text: "登録済みのGoogleアカウントでログインしてください"
    assert_select ".flash.alert[data-controller='flash']"
  end

  it "seed admin email can bootstrap first production login" do
    with_seed_admin(email: "kim@localworks.jp", name: "Kim") do
      mock_google_auth("kim@localworks.jp")

      post "/auth/google_oauth2"
      follow_all_redirects
    end

    admin = User.find_by(email: "kim@localworks.jp")
    assert_response :success
    assert_select ".home-copy-line", text: "Kimさん"
    assert_select "a", text: "管理画面"
    assert_equal "Kim", admin.name
    assert admin.survey_subject?
    assert admin.system_admin?
  end

  it "missing google configuration route stays inside app" do
    post "/auth/google_oauth2", env: { "omniauth.test_mode" => false }

    assert_response :redirect
  end

  it "login greeting changes by time of day" do
    {
      Time.zone.local(2026, 6, 7, 9, 59) => "おはようございます。",
      Time.zone.local(2026, 6, 7, 10, 0) => "こんにちは。",
      Time.zone.local(2026, 6, 7, 16, 59) => "こんにちは。",
      Time.zone.local(2026, 6, 7, 17, 0) => "こんばんは。"
    }.each do |current_time, greeting|
      travel_to current_time do
        get login_path

        assert_response :success
        assert_select "#login-copy-heading", text: greeting
      end
    end
  end

  it "stale google callback redirects to login" do
    OmniAuth.config.test_mode = false

    get "/auth/google_oauth2/callback", params: { state: "stale-state", code: "stale-code" }

    assert_redirected_to login_path
  end

  it "development login is unavailable outside development" do
    post development_login_path

    assert_response :not_found
  end

  it "logout redirects to login screen" do
    user = User.create!(name: "登録済み", email: "logout@example.com")

    login_as(user)
    delete logout_path

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".flash.notice", text: "ログアウトしました"
    assert_select ".flash.notice[data-controller='flash']"
    assert_select ".home-meta-val", text: "登録済みアカウントでログイン", count: 0
    assert_select "button.google-login-button", text: /Google でログイン/
  end

  it "rails admin is restricted to system admins" do
    system_admin_role = Role.create!(name: "system_admin")
    admin = User.create!(name: "管理者", email: "admin@example.com")
    admin.roles << system_admin_role
    member = User.create!(name: "一般", email: "member@example.com")

    get rails_admin_path
    follow_redirect!
    assert_select ".flash.alert", text: "ログインしてください"

    login_as(member)
    get rails_admin_path
    follow_redirect!
    assert_select ".flash.alert", text: "管理者権限が必要です"

    login_as(admin)
    get rails_admin_path
    assert_response :success
  end

  private

  def mock_google_auth(email)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "uid-#{email}",
      info: { email: email, name: "Google User" }
    )
  end

  def login_as(user)
    mock_google_auth(user.email)
    post "/auth/google_oauth2"
    follow_all_redirects
  end

  def with_seed_admin(email:, name:)
    previous_email = ENV["SEED_ADMIN_EMAIL"]
    previous_name = ENV["SEED_ADMIN_NAME"]
    ENV["SEED_ADMIN_EMAIL"] = email
    ENV["SEED_ADMIN_NAME"] = name
    yield
  ensure
    ENV["SEED_ADMIN_EMAIL"] = previous_email
    ENV["SEED_ADMIN_NAME"] = previous_name
  end

  def follow_all_redirects
    follow_redirect! while response.redirect?
  end
end
