# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::GorseClient do
  around do |example|
    ClimateControl.modify RINSPACE_GORSE_ENDPOINT: 'https://gorse.internal', RINSPACE_GORSE_API_KEY: 'server-only-key' do
      example.run
    end
  end

  it 'keeps credentials server-side and accepts only Mastodon status IDs' do
    request = stub_request(:get, 'https://gorse.internal/api/recommend/subject%2F1?n=10&offset=0&category=mastodon-status')
      .with(headers: { 'X-API-Key' => 'server-only-key' })
      .to_return(status: 200, body: ['mastodon-status:12', 'foreign:13', 'mastodon-status:12'].to_json)

    expect(described_class.new.recommend(user_id: 'subject/1', limit: 10)).to eq([12])
    expect(request).to have_been_requested.once
  end

  it 'fails closed when configuration or the service is invalid' do
    stub_request(:get, /gorse\.internal/).to_return(status: 503)
    expect { described_class.new.recommend(user_id: 'subject', limit: 10) }.to raise_error(described_class::UnavailableError)

    ClimateControl.modify RINSPACE_GORSE_ENDPOINT: 'https://user@example.com/path' do
      expect { described_class.new.recommend(user_id: 'subject', limit: 10) }.to raise_error(described_class::UnavailableError)
    end
  end
end
