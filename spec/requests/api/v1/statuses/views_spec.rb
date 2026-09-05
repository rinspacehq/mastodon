# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Status views', :inline_jobs do
  let(:user) { Fabricate(:user) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'write:statuses') }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}", 'User-Agent' => 'Rinspace Browser' } }
  let(:status) { Fabricate(:status, visibility: :public) }

  around do |example|
    ClimateControl.modify RINSPACE_IDENTITY_STRICT: 'true', RINSPACE_VIEW_DEDUPE_HMAC_KEY: 'v' * 32, RINSPACE_LOCAL_ONLY: 'false' do
      example.run
    end
  end

  before do
    RinspaceIdentityBinding.create!(subject: "view-#{user.id}", account: user.account, current_handle: user.account.username, profile_version: 1)
    RedisConnection.with { |redis| redis.scan_each(match: 'rinspace:status-view:*').each { |key| redis.del(key) } }
  end

  it 'counts once per viewer, status, and session during the five-minute window' do
    2.times do
      post "/api/v1/statuses/#{status.id}/view", params: { sessionId: 'session-1234567890', recommendationSignal: false }, headers: headers
      expect(response).to have_http_status(:ok)
    end
    expect(status.reload.views_count).to eq(1)

    post "/api/v1/statuses/#{status.id}/view", params: { sessionId: 'session-0987654321', recommendationSignal: false }, headers: headers
    expect(status.reload.views_count).to eq(2)
  end

  it 'does not count direct messages, prefetches, or bots' do
    direct = Fabricate(:status, account: user.account, visibility: :direct)
    post "/api/v1/statuses/#{direct.id}/view", params: { sessionId: 'session-1234567890' }, headers: headers
    expect(response.parsed_body['counted']).to be false

    post "/api/v1/statuses/#{status.id}/view", params: { sessionId: 'session-1234567890' }, headers: headers.merge('Sec-Purpose' => 'prefetch')
    expect(status.reload.views_count).to eq(0)

    post "/api/v1/statuses/#{status.id}/view", params: { sessionId: 'session-0987654321' }, headers: headers.merge('User-Agent' => 'ExampleBot/1.0')
    expect(status.reload.views_count).to eq(0)
  end

  it 'does not count when the rollout view gate is disabled' do
    allow(Rails.configuration.x.mastodon).to receive(:rinspace_views_enabled).and_return(false)

    post "/api/v1/statuses/#{status.id}/view", params: { sessionId: 'session-1234567890' }, headers: headers

    expect(response).to have_http_status(:not_found)
    expect(status.reload.views_count).to eq(0)
  end
end
