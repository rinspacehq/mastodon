# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tweet knowledge Tag hydration data' do
  let(:account) { Fabricate(:account) }
  let(:status) { Fabricate(:status, account:, visibility: :public, rinspace_review_state: 'approved') }
  let(:tag) { Fabricate(:tag, name: 'oldname') }

  before do
    status.tags << tag
  end

  it 'exposes bounded verified outer Tag identities on the single-status API' do
    RinspaceTagBinding.create!(tag:, rinspace_tag_id: 42, canonical_name: 'new-name', binding_version: 2, state: 'verified')

    get "/api/v1/statuses/#{status.id}"

    expect(response).to have_http_status(200)
    expect(response.parsed_body['rinspace_knowledge_tags']).to contain_exactly(
      { 'id' => '42', 'name' => 'new-name', 'url' => 'https://rinspace.com/tags/42/new-name' }
    )
  end

  it 'omits the outer relation when the Tweet is not externally indexable' do
    RinspaceTagBinding.create!(tag:, rinspace_tag_id: 42, canonical_name: 'new-name', binding_version: 2, state: 'verified')
    account.user.settings.update('noindex' => true)
    account.user.save!

    get "/api/v1/statuses/#{status.id}"

    expect(response).to have_http_status(200)
    expect(response.parsed_body).not_to have_key('rinspace_knowledge_tags')
  end

  it 'does not expose unverified bindings' do
    RinspaceTagBinding.create!(tag:, rinspace_tag_id: 42, canonical_name: 'new-name', binding_version: 2, state: 'pending')

    get "/api/v1/statuses/#{status.id}"

    expect(response).to have_http_status(200)
    expect(response.parsed_body['rinspace_knowledge_tags']).to be_empty
  end
end
