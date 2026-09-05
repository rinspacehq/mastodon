# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mastodon::Middleware::RinspaceLocalOnly do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(_env) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }

  around do |example|
    original = Rails.configuration.x.mastodon.rinspace_local_only
    Rails.configuration.x.mastodon.rinspace_local_only = true
    example.run
  ensure
    Rails.configuration.x.mastodon.rinspace_local_only = original
  end

  it 'returns a non-cacheable 404 for WebFinger' do
    status, headers, body = middleware.call('PATH_INFO' => '/.well-known/webfinger', 'REQUEST_METHOD' => 'GET')

    expect(status).to eq 404
    expect(headers).to include('Cache-Control' => 'no-store', 'X-Rinspace-Local-Only' => 'blocked')
    expect(body.join).to include('local_only.federation_disabled')
  end

  it 'blocks ActivityPub negotiation on an account page' do
    status, = middleware.call('PATH_INFO' => '/@alice', 'REQUEST_METHOD' => 'GET', 'HTTP_ACCEPT' => 'application/activity+json')

    expect(status).to eq 404
  end

  it 'passes an ordinary local REST request through' do
    status, = middleware.call('PATH_INFO' => '/api/v1/timelines/home', 'REQUEST_METHOD' => 'GET', 'HTTP_ACCEPT' => 'application/json')

    expect(status).to eq 200
  end
end
