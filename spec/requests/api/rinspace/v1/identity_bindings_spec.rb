# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace identity binding API' do
  around do |example|
    ClimateControl.modify RINSPACE_CONTROL_PLANE_HMAC_KEY: 'k' * 32 do
      example.run
    end
  end

  it 'requires a fresh signed request and rejects replay' do
    body = { subject: 'api-uid', handle: 'apiuser', displayName: 'API User', version: 1 }.to_json
    headers = signed_headers('/api/rinspace/v1/identity_bindings', body, nonce: 'n' * 20)

    post '/api/rinspace/v1/identity_bindings', params: body, headers: headers
    expect(response).to have_http_status(:ok)
    account_id = response.parsed_body['accountId']

    post '/api/rinspace/v1/identity_bindings', params: body, headers: headers
    expect(response).to have_http_status(:unauthorized)
    expect(RinspaceIdentityBinding.find_by(subject: 'api-uid').account_id).to eq(account_id)
  end

  it 'rejects an unsigned request' do
    post '/api/rinspace/v1/identity_bindings', params: { subject: 'x', handle: 'x', version: 1 }
    expect(response).to have_http_status(:unauthorized)
  end

  def signed_headers(path, body, nonce:)
    timestamp = Time.now.to_i.to_s
    body_hash = OpenSSL::Digest::SHA256.hexdigest(body)
    canonical = ['POST', path, timestamp, nonce, body_hash].join("\n")
    signature = OpenSSL::HMAC.hexdigest('SHA256', 'k' * 32, canonical)
    { 'CONTENT_TYPE' => 'application/json', 'X-Rin-Service' => 'rin-control-plane', 'X-Rin-Timestamp' => timestamp, 'X-Rin-Nonce' => nonce, 'X-Rin-Signature' => signature }
  end
end
