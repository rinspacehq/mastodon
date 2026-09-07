# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace shared composer API' do
  let(:user) { Fabricate(:user, account_attributes: { username: 'composer_user' }) }

  before do
    RinspaceIdentityBinding.create!(
      subject: 'composer-subject',
      account: user.account,
      current_handle: user.account.username,
      profile_version: 1,
      state: 'verified'
    )
  end

  around do |example|
    ClimateControl.modify(
      RINSPACE_APP_HMAC_KEY: 'a' * 32,
      RINSPACE_CONTROL_PLANE_HMAC_KEY: 'c' * 32,
      RINSPACE_IDENTITY_STRICT: 'false'
    ) do
      example.run
    end
  end

  it 'returns the native Mastodon limits for a verified Rinspace subject' do
    path = '/api/rinspace/v1/composer/config?subject=composer-subject'

    get path, headers: signed_headers('GET', path, '', nonce: 'config-request-nonce')

    expect(response).to have_http_status(200)
    expect(response.parsed_body).to include(
      'maxCharacters' => StatusLengthValidator::MAX_CHARS,
      'maxMediaAttachments' => Status::MEDIA_ATTACHMENTS_LIMIT,
      'pollMaxOptions' => PollOptionsValidator::MAX_OPTIONS,
      'defaultVisibility' => 'public'
    )
    expect(response.parsed_body.fetch('languages')).to include(include('code' => 'zh-CN'))
  end

  it 'returns only distributable native statuses using the public projection contract' do
    public_status = Fabricate(:status, account: user.account, text: 'A projected Rinspace tweet', visibility: :public)
    Fabricate(:status, account: user.account, text: 'A private draft', visibility: :private)
    path = '/api/rinspace/v1/composer/accounts/composer-subject/statuses'

    get path, headers: signed_headers('GET', path, '', nonce: 'status-request-nonce')

    expect(response).to have_http_status(200)
    expect(response.parsed_body).to include('accountId' => user.account.id.to_s, 'nextMaxId' => nil)
    expect(response.parsed_body.fetch('items')).to contain_exactly(
      include(
        'id' => public_status.id.to_s,
        'content' => include('A projected Rinspace tweet'),
        'visibility' => 'public',
        'media' => []
      )
    )
  end

  it 'publishes through the bound native account with the supplied idempotency key' do
    path = '/api/rinspace/v1/composer/statuses'
    body = {
      subject: 'composer-subject',
      text: 'A native shared-composer tweet',
      sensitive: false,
      spoilerText: '',
      visibility: 'public',
      language: 'en',
      mediaIds: [],
      poll: nil,
      idempotencyKey: 'composer-request-123',
    }.to_json
    headers = signed_headers('POST', path, body, nonce: 'publish-request-nonce').merge('Idempotency-Key' => 'composer-request-123')

    post path, params: body, headers: headers

    expect(response).to have_http_status(200)
    status = user.account.statuses.find(response.parsed_body.fetch('id'))
    expect(status).to have_attributes(text: 'A native shared-composer tweet', visibility: 'public')
  end

  it 'does not let the application service reuse the control-plane credential' do
    path = '/api/rinspace/v1/composer/config?subject=composer-subject'
    headers = signed_headers('GET', path, '', nonce: 'wrong-service-nonce', key: 'c' * 32)

    get path, headers: headers

    expect(response).to have_http_status(401)
  end

  def signed_headers(method, path, body, nonce:, key: 'a' * 32)
    timestamp = Time.now.to_i.to_s
    body_hash = OpenSSL::Digest::SHA256.hexdigest(body)
    canonical = [method, path, timestamp, nonce, body_hash].join("\n")
    signature = OpenSSL::HMAC.hexdigest('SHA256', key, canonical)
    {
      'CONTENT_TYPE' => 'application/json',
      'X-Rin-Service' => 'rinspace',
      'X-Rin-Timestamp' => timestamp,
      'X-Rin-Nonce' => nonce,
      'X-Rin-Signature' => signature,
    }
  end
end
