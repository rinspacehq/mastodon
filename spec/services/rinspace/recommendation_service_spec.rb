# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::RecommendationService do
  around do |example|
    ClimateControl.modify RINSPACE_GORSE_ENDPOINT: 'https://gorse.internal', RINSPACE_GORSE_API_KEY: 'gorse-test-key' do
      example.run
    end
  end

  it 'lets Gorse rank but applies local visibility, moderation, account, and block filters' do
    viewer = Fabricate(:account)
    author = Fabricate(:account, discoverable: true)
    allowed = Fabricate(:status, account: author, visibility: :public, rinspace_review_state: 'approved')
    private_status = Fabricate(:status, account: author, visibility: :private, rinspace_review_state: 'approved')
    unreviewed = Fabricate(:status, account: author, visibility: :public, rinspace_review_state: 'unreviewed')
    stub_request(:get, /gorse\.internal\/api\/recommend/).to_return(
      status: 200,
      body: ["mastodon-status:#{private_status.id}", "mastodon-status:#{unreviewed.id}", "mastodon-status:#{allowed.id}", 'other:1'].to_json
    )

    result = described_class.new.call(account: viewer, subject: 'uid-viewer', limit: 20)
    expect(result.map(&:id)).to eq([allowed.id])

    viewer.block!(author)
    expect(described_class.new.call(account: viewer, subject: 'uid-viewer', limit: 20)).to be_empty
  end

  it 'uses a filtered recent fallback when Gorse is unavailable' do
    viewer = Fabricate(:account)
    allowed = Fabricate(:status, account: Fabricate(:account, discoverable: true), visibility: :public, rinspace_review_state: 'approved')
    stub_request(:get, /gorse\.internal/).to_return(status: 503)

    expect(described_class.new.call(account: viewer, subject: 'uid-viewer', limit: 20).map(&:id)).to include(allowed.id)
  end

  it 'fills a short personalized result with distinct eligible local statuses' do
    viewer = Fabricate(:account)
    author = Fabricate(:account, discoverable: true)
    ranked = Fabricate(:status, account: author, visibility: :public, rinspace_review_state: 'approved')
    fallback = Fabricate(:status, account: author, visibility: :public, rinspace_review_state: 'approved')
    stub_request(:get, /gorse\.internal\/api\/recommend/).to_return(
      status: 200,
      body: ["mastodon-status:#{ranked.id}"].to_json
    )

    result = described_class.new.call(account: viewer, subject: 'uid-viewer', limit: 2)

    expect(result.map(&:id)).to eq([ranked.id, fallback.id])
  end
end
