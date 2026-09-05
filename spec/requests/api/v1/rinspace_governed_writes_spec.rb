# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace governed writes' do
  let(:user) { Fabricate(:user) }
  let(:application) { Fabricate(:application) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, application:, scopes: 'write:statuses write:media write:accounts') }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  around do |example|
    ClimateControl.modify RINSPACE_IDENTITY_STRICT: 'true' do
      example.run
    end
  end

  it 'rejects every authenticated API mutation without a verified subject binding' do
    post '/api/v1/statuses', params: { status: 'hello', visibility: 'public' }, headers: headers
    expect(response).to have_http_status(:forbidden)
    expect(Status.where(account: user.account)).to be_empty
  end

  it 'fails closed before identity checks when the rollout write gate is disabled' do
    allow(Rails.configuration.x.mastodon).to receive(:rinspace_community_write_enabled).and_return(false)
    bind_user

    post '/api/v1/statuses', params: { status: 'hello', visibility: 'public' }, headers: headers

    expect(response).to have_http_status(:service_unavailable)
    expect(response.headers['Retry-After']).to eq('300')
    expect(Status.where(account: user.account)).to be_empty
  end

  it 'reviews status text, content warnings, and poll options before creating content' do
    bind_user
    reviewer = instance_double(Rinspace::ModerationClient)
    allow(Rinspace::ModerationClient).to receive(:new).and_return(reviewer)
    allow(reviewer).to receive(:review_text!).and_raise(Rinspace::ModerationRejectedError)

    post '/api/v1/statuses', params: { status: 'body', spoiler_text: 'warning', visibility: 'public', poll: { options: ['one', 'two'], expires_in: 3600 } }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(Status.where(account: user.account)).to be_empty
    expect(reviewer).to have_received(:review_text!).with(hash_including(subject: "governed-#{user.id}", text: "warning\nbody\none\ntwo"))
  end

  it 'reviews media descriptions and rejects edits to identity-owned profile fields' do
    bind_user
    reviewer = instance_double(Rinspace::ModerationClient)
    allow(Rinspace::ModerationClient).to receive(:new).and_return(reviewer)
    allow(reviewer).to receive(:review_text!).and_raise(Rinspace::ModerationRejectedError)

    post '/api/v1/media', params: { description: 'unsafe description' }, headers: headers
    expect(response).to have_http_status(:unprocessable_content)

    patch '/api/v1/accounts/update_credentials', params: { display_name: 'second source' }, headers: headers
    expect(response).to have_http_status(:forbidden)
  end

  def bind_user
    RinspaceIdentityBinding.create!(subject: "governed-#{user.id}", account: user.account, current_handle: user.account.username, profile_version: 1)
  end
end
