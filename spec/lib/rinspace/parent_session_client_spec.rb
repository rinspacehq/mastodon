# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::ParentSessionClient do
  subject(:client) { described_class.new(http_request:, clock:, nonce:) }

  let(:clock) { class_double(Time, now: Time.zone.at(1_789_200_000)) }
  let(:nonce) { class_double(SecureRandom, urlsafe_base64: 'prototype-nonce-value') }
  let(:uid) { 'uid-7' }
  let(:sid) { SecureRandom.uuid }
  let(:response) { http_response(Net::HTTPOK, active: true, currentVersion: 7) }
  let(:http_request) { ->(_endpoint, _request) { response } }

  around do |example|
    ClimateControl.modify(
      OIDC_ISSUER: 'https://rinspace.example',
      RINSPACE_IDENTITY_INTERNAL_URL: 'https://identity.internal',
      RINSPACE_IDENTITY_SERVICE_ID: 'mastodon',
      RINSPACE_IDENTITY_SERVICE_KEY_ID: 'current',
      RINSPACE_IDENTITY_SERVICE_SECRET: 'prototype-secret-with-at-least-32-bytes',
      RINSPACE_IDENTITY_AUDIENCE: 'mastodon'
    ) { example.run }
  end

  it 'accepts an exact active parent version using a signed status request' do
    captured = nil
    allow(http_request).to receive(:call) do |endpoint, request|
      captured = [endpoint, request]
      response
    end

    expect(client.assert_active!(issuer: 'https://rinspace.example', uid:, sid:, version: 7)).to be true
    expect(captured.first.path).to eq("/internal/v1/identity/sessions/#{sid}/status")
    expect(JSON.parse(captured.last.body)).to include('sid' => sid, 'uid' => uid, 'issuedVersion' => 7, 'audience' => 'mastodon')
    expect(captured.last['X-Rin-Signature']).to be_present
    expect(captured.last['X-Rin-Key-ID']).to eq('current')
  end

  it 'creates, activates, fails, and revokes only opaque runtime binding ids' do
    binding_id = SecureRandom.uuid
    responses = [
      http_response(Net::HTTPOK, id: binding_id, sid:, runtime: 'mastodon', issuedVersion: 7),
      http_response(Net::HTTPNoContent), http_response(Net::HTTPNoContent), http_response(Net::HTTPNoContent)
    ]
    bodies = []
    allow(http_request).to receive(:call) do |_endpoint, request|
      bodies << JSON.parse(request.body)
      responses.shift
    end

    expect(client.create_binding!(issuer: 'https://rinspace.example', uid:, sid:, version: 7)['id']).to eq(binding_id)
    expect(client.activate_binding!(uid:, binding_id:, runtime_ref: '91', issued_version: 7)).to be true
    expect(client.fail_binding!(uid:, binding_id:)).to be true
    expect(client.revoke_parent!(uid:, sid:, binding_id:)).to be true
    expect(bodies.map { |body| body['operation'] }).to eq(%w[create activate fail revoke])
  end

  it 'rejects an inactive or stale parent' do
    allow(response).to receive(:body).and_return(JSON.generate(active: false, currentVersion: 7))
    expect { client.assert_active!(issuer: 'https://rinspace.example', uid:, sid:, version: 7) }
      .to raise_error(described_class::InactiveError)
  end

  it 'fails closed when the identity service is unavailable' do
    allow(http_request).to receive(:call).and_return(http_response(Net::HTTPServiceUnavailable))
    expect { client.assert_active!(issuer: 'https://rinspace.example', uid:, sid:, version: 7) }
      .to raise_error(described_class::UnavailableError)
  end

  def http_response(klass, body = nil)
    code = klass == Net::HTTPOK ? '200' : klass == Net::HTTPNoContent ? '204' : '503'
    klass.new('1.1', code, '').tap do |value|
      value.instance_variable_set(:@read, true)
      value.body = JSON.generate(body) if body
    end
  end
end
