settings = Rails.application.config_for(:settings).deep_symbolize_keys

SERVICE_URL = settings.fetch(:service_url)
