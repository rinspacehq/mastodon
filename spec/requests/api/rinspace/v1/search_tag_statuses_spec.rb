# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace search Tag statuses adapter' do
  let(:key) { 'k' * 32 }
  let(:tag) { Fabricate(:tag, name: 'algebraicgeometry') }
  let(:account) { Fabricate(:account) }

  def signed_get(path)
    timestamp = Time.now.to_i.to_s
    nonce = SecureRandom.hex(16)
    body_hash = OpenSSL::Digest::SHA256.hexdigest('')
    canonical = ['GET', path, timestamp, nonce, body_hash].join("\n")
    get path, headers: {
      'X-Rin-Service' => 'rinspace', 'X-Rin-Timestamp' => timestamp, 'X-Rin-Nonce' => nonce,
      'X-Rin-Signature' => OpenSSL::HMAC.hexdigest('SHA256', key, canonical),
    }
  end

  around do |example|
    ClimateControl.modify RINSPACE_APP_HMAC_KEY: key, RINSPACE_CONTROL_PLANE_HMAC_KEY: 'c' * 32 do
      example.run
    end
  end

  it 'returns only bounded, eligible statuses for a verified binding without body fields' do
    binding = RinspaceTagBinding.create!(tag:, rinspace_tag_id: 42, canonical_name: 'algebraic-geometry', binding_version: 3, state: 'verified')
    eligible = Fabricate(:status, account:, text: 'Eligible tagged Tweet', visibility: :public, rinspace_review_state: 'approved')
    eligible.tags << tag
    excluded = Fabricate(:status, account:, text: 'Private tagged Tweet', visibility: :private, rinspace_review_state: 'approved')
    excluded.tags << tag

    signed_get "/api/rinspace/v1/search/tags/#{binding.rinspace_tag_id}/statuses"

    expect(response).to have_http_status(200)
    payload = response.parsed_body
    expect(payload['bindingVersion']).to eq(3)
    expect(payload['items']).to contain_exactly(include('id' => eligible.id.to_s, 'canonicalUrl' => canonical_rinspace_status_url(eligible.id, 'eligible-tagged-tweet')))
    expect(payload.to_json).not_to include('Private tagged Tweet')
    expect(payload['items'].first.keys).to match_array(%w[id title canonicalUrl publicModifiedAt])
  end

  %w[pending retired conflicting unbound].each do |state|
    it "does not expose #{state} bindings" do
      RinspaceTagBinding.create!(tag:, rinspace_tag_id: 42, canonical_name: 'tag', binding_version: 1, state:)

      signed_get '/api/rinspace/v1/search/tags/42/statuses'

      expect(response).to have_http_status(404)
    end
  end
end
