# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace interaction persistence', :inline_jobs do
  let(:author) { Fabricate(:user) }
  let(:actor) { Fabricate(:user) }
  let(:application) { Fabricate(:application) }
  let(:token) do
    Fabricate(
      :accessible_access_token,
      resource_owner_id: actor.id,
      application:,
      scopes: 'read:statuses write:statuses write:favourites write:bookmarks'
    )
  end
  let(:headers) { { 'Authorization' => "Bearer #{token.token}", 'User-Agent' => 'Rinspace Browser' } }
  let(:status) do
    Fabricate(
      :status,
      account: author.account,
      visibility: :public,
      rinspace_review_state: 'approved'
    )
  end

  around do |example|
    ClimateControl.modify(
      RINSPACE_IDENTITY_STRICT: 'true',
      RINSPACE_LOCAL_ONLY: 'true',
      RINSPACE_VIEW_DEDUPE_HMAC_KEY: 'v' * 32
    ) { example.run }
  end

  before do
    [author, actor].each do |user|
      RinspaceIdentityBinding.create!(
        subject: "interaction-#{user.id}",
        account: user.account,
        current_handle: user.account.username,
        profile_version: 1
      )
    end
    reviewer = instance_double(Rinspace::ModerationClient, review_text!: true)
    allow(Rinspace::ModerationClient).to receive(:new).and_return(reviewer)
    gorse = instance_double(Rinspace::GorseClient, feedback: true, upsert_status: true)
    allow(Rinspace::GorseClient).to receive(:new).and_return(gorse)
    RedisConnection.with { |redis| redis.scan_each(match: 'rinspace:status-view:*').each { |key| redis.del(key) } }
  end

  it 'persists reply, reblog, favourite, bookmark, view count, and recipient notifications' do
    2.times do
      post "/api/v1/statuses/#{status.id}/favourite", headers: headers
      expect(response).to have_http_status(:ok)
      post "/api/v1/statuses/#{status.id}/bookmark", headers: headers
      expect(response).to have_http_status(:ok)
      post "/api/v1/statuses/#{status.id}/reblog", headers: headers
      expect(response).to have_http_status(:ok)
      post "/api/v1/statuses/#{status.id}/view", params: { sessionId: 'interaction-session-1234', recommendationSignal: false }, headers: headers
      expect(response).to have_http_status(:ok)
    end

    post '/api/v1/statuses', params: { status: "@#{author.account.username} persisted reply", in_reply_to_id: status.id, visibility: 'public' }, headers: headers
    expect(response).to have_http_status(:ok)
    reply_id = response.parsed_body[:id]

    expect(Favourite.where(account: actor.account, status:).count).to eq(1)
    expect(Bookmark.where(account: actor.account, status:).count).to eq(1)
    expect(Status.where(account: actor.account, reblog_of_id: status.id).count).to eq(1)
    expect(Status.find(reply_id)).to have_attributes(in_reply_to_id: status.id, rinspace_review_state: 'approved')
    expect(status.reload.views_count).to eq(1)
    expect(author.account.notifications.where(from_account: actor.account).pluck(:activity_type)).to include('Favourite', 'Status')

    get "/api/v1/statuses/#{status.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      favourited: true,
      bookmarked: true,
      reblogged: true,
      favourites_count: 1,
      reblogs_count: 1,
      views_count: 1
    )
  end
end
