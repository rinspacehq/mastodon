# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace recommendation preferences' do
  let(:user) { Fabricate(:user) }
  let(:read_token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'read:accounts') }
  let(:write_token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: 'write:accounts') }

  around do |example|
    ClimateControl.modify RINSPACE_IDENTITY_STRICT: 'true', RINSPACE_GORSE_ENDPOINT: 'https://gorse.internal', RINSPACE_GORSE_API_KEY: 'server-key' do
      example.run
    end
  end

  before do
    RinspaceIdentityBinding.create!(subject: "preference-#{user.id}", account: user.account, current_handle: user.account.username, profile_version: 1)
  end

  it 'persists feed choice and lets the user inspect and remove normalized interests' do
    put '/api/v1/rinspace_preferences', params: { personalizedRecommendations: true, homeFeed: 'recommended', interests: ['#Ruby', 'Ruby', '../bad'] }, headers: authorization(write_token)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('personalizedRecommendations' => true, 'homeFeed' => 'recommended', 'interests' => ['Ruby'])

    delete '/api/v1/rinspace_preferences/interests/Ruby', headers: authorization(write_token)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['interests']).to be_empty

    get '/api/v1/rinspace_preferences', headers: authorization(read_token)
    expect(response.parsed_body['interests']).to be_empty
  end

  it 'clears the Gorse profile and disables all personalization only after confirmation' do
    request = stub_request(:delete, "https://gorse.internal/api/user/preference-#{user.id}")
      .with(headers: { 'X-API-Key' => 'server-key' })
      .to_return(status: 200, body: '{}')

    delete '/api/v1/rinspace_preferences', headers: authorization(write_token)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('personalizedRecommendations' => false, 'homeFeed' => 'following', 'profileCleared' => true)
    expect(request).to have_been_requested.once
  end

  def authorization(token)
    { 'Authorization' => "Bearer #{token.token}" }
  end
end
