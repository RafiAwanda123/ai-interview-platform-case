# frozen_string_literal: true

module AuthHelper
  def auth_headers(org, role: 'admin', user_id: 1)
    token = JsonWebToken.encode(user_id: user_id, role: role, scheme: org.scheme)
    {
      'Authorization' => "Bearer #{token}",
      'Host' => org.host
    }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end

