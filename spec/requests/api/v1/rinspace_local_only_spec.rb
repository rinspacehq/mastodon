# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace local-only REST boundary' do
  around do |example|
    original = Rails.configuration.x.mastodon.rinspace_local_only
    Rails.configuration.x.mastodon.rinspace_local_only = true
    example.run
  ensure
    Rails.configuration.x.mastodon.rinspace_local_only = original
  end

  it 'does not expose a cached remote account' do
    remote_account = Fabricate(:account, domain: 'example.org')

    get "/api/v1/accounts/#{remote_account.id}"

    expect(response).to have_http_status(404)
  end

  it 'does not expose a cached remote status' do
    remote_status = Fabricate(:status, account: Fabricate(:account, domain: 'example.org'))

    get "/api/v1/statuses/#{remote_status.id}"

    expect(response).to have_http_status(404)
  end

  it 'does not expose federation administration APIs' do
    get '/api/v1/admin/domain_allows', headers: { 'Authorization' => 'Bearer invalid' }

    expect(response).to have_http_status(404)
    expect(response.headers['X-Rinspace-Local-Only']).to eq 'blocked'
  end
end
