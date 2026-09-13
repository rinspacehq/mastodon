# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::BackchannelLogoutService do
  subject(:service) { described_class.new(decoder:, clock:) }

  let(:now) { Time.zone.at(1_789_200_000) }
  let(:clock) { class_double(Time, now:) }
  let(:sid) { SecureRandom.uuid }
  let(:claims) do
    {
      'iss' => 'https://rinspace.example',
      'sub' => 'uid-a',
      'aud' => 'mastodon-client',
      'iat' => now.to_i,
      'exp' => 4.minutes.from_now(now).to_i,
      'jti' => SecureRandom.uuid,
      'sid' => sid,
      'rin_session_version' => 3,
      'events' => { described_class::EVENT_URI => {} },
    }
  end
  let(:decoder) { instance_double(Rinspace::BackchannelJwtDecoder, decode: claims) }

  around do |example|
    ClimateControl.modify(OIDC_ISSUER: 'https://rinspace.example', OIDC_CLIENT_ID: 'mastodon-client') { example.run }
  end

  it 'records the jti and removes only the matching parent through its event version' do
    expect(SessionActivation).to receive(:deactivate_rinspace_parent).with(issuer: 'https://rinspace.example', sid:, version: 3)

    expect { service.call('a.b.c') }.to change(RinspaceLogoutEvent, :count).by(1)
  end

  it 'rejects wrong issuer, audience, expiry, nonce, event shape, and invalid sid' do
    invalid_claims = [
      claims.merge('iss' => 'https://attacker.example'),
      claims.merge('aud' => 'another-client'),
      claims.merge('exp' => now.to_i),
      claims.merge('nonce' => 'must-not-be-present'),
      claims.merge('events' => {}),
      claims.merge('sid' => 'uid-is-not-a-session-capability'),
    ]

    invalid_claims.each do |candidate|
      allow(decoder).to receive(:decode).and_return(candidate)
      expect { service.call('a.b.c') }.to raise_error(described_class::InvalidTokenError)
    end
  end

  it 'rejects a replayed jti without running local cleanup twice' do
    allow(SessionActivation).to receive(:deactivate_rinspace_parent)
    service.call('a.b.c')

    expect { service.call('a.b.c') }.to raise_error(described_class::InvalidTokenError)
    expect(SessionActivation).to have_received(:deactivate_rinspace_parent).once
  end
end
