# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rinspace::ManagedSessionActivationService do
  subject(:service) { described_class.new(parent_authorizer:) }

  let(:user) { Fabricate(:user) }
  let(:issuer) { 'https://rinspace.example' }
  let(:uid) { 'uid-4' }
  let(:sid) { SecureRandom.uuid }
  let(:binding_id) { SecureRandom.uuid }
  let(:auth_time) { Time.zone.at(1_789_200_000) }
  let(:parent) { { user:, issuer:, uid:, sid:, version: 4, auth_time: } }
  let(:grant) { { 'id' => binding_id, 'sid' => sid, 'runtime' => 'mastodon', 'issuedVersion' => 5 } }
  let(:parent_authorizer) do
    instance_double(
      Rinspace::ParentSessionClient,
      create_binding!: grant,
      activate_binding!: true,
      fail_binding!: true
    )
  end

  it 'returns a browser activation only after its pending binding is activated' do
    activation = service.call(session_id: 'browser-session', **parent)

    expect(activation).to be_persisted.and be_rinspace_managed
    expect(activation).to have_attributes(
      rinspace_parent_uid: uid,
      rinspace_parent_version: 5,
      rinspace_parent_auth_time: auth_time,
      rinspace_binding_id: binding_id
    )
    expect(parent_authorizer).to have_received(:create_binding!).with(issuer:, uid:, sid:, version: 4).ordered
    expect(parent_authorizer).to have_received(:activate_binding!).with(uid:, binding_id:, runtime_ref: activation.id, issued_version: 5).ordered
  end

  it 'removes the activation and fails the binding when activation loses a revocation race' do
    allow(parent_authorizer).to receive(:activate_binding!).and_raise(Rinspace::ParentSessionClient::InactiveError)

    expect do
      service.call(session_id: 'browser-session', **parent)
    end.to raise_error(Rinspace::ParentSessionClient::InactiveError)
      .and not_change(SessionActivation, :count)
      .and not_change(Doorkeeper::AccessToken, :count)

    expect(parent_authorizer).to have_received(:fail_binding!).with(uid:, binding_id:)
  end

  it 'reuses the activation bound to the same parent session instead of creating a second binding' do
    existing = Fabricate(
      :session_activation,
      user:,
      session_id: 'existing-browser-session',
      rinspace_parent_issuer: issuer,
      rinspace_parent_uid: uid,
      rinspace_parent_sid: sid,
      rinspace_parent_version: 2,
      rinspace_parent_auth_time: auth_time,
      rinspace_binding_id: binding_id
    )

    expect(service.call(session_id: 'another-browser-session', **parent)).to eq(existing)
    expect(parent_authorizer).to_not have_received(:create_binding!)
    expect(parent_authorizer).to_not have_received(:activate_binding!)
    expect(user.session_activations.count).to eq(1)
  end

end
