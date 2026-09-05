# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Recommended timeline rollout gate' do
  let(:user) { Fabricate(:user) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'read:statuses') }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  before do
    RinspaceIdentityBinding.create!(subject: "recommended-#{user.id}", account: user.account, current_handle: user.account.username, profile_version: 1)
  end

  it 'does not expose recommendation results when the rollout gate is disabled' do
    allow(Rails.configuration.x.mastodon).to receive(:rinspace_recommendations_enabled).and_return(false)

    get '/api/v1/timelines/recommended', headers: headers

    expect(response).to have_http_status(:not_found)
  end
end
