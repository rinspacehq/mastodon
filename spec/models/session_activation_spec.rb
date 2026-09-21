# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionActivation do
  it_behaves_like 'BrowserDetection'

  describe '.active?' do
    subject { described_class.active?(id) }

    context 'when id is absent' do
      let(:id) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when id is present' do
      let(:id) { '1' }
      let!(:session_activation) { Fabricate(:session_activation, session_id: id) }

      context 'when id exists as session_id' do
        it 'returns true' do
          expect(subject).to be true
        end
      end

      context 'when id does not exist as session_id' do
        before do
          session_activation.update!(session_id: '2')
        end

        it 'returns false' do
          expect(subject).to be false
        end
      end
    end
  end

  describe '.activate' do
    let(:user) { Fabricate :user }
    let!(:session_activation) { Fabricate :session_activation, user: }

    around do |example|
      original = Rails.configuration.x.max_session_activations
      Rails.configuration.x.max_session_activations = 1
      example.run
      Rails.configuration.x.max_session_activations = original
    end

    it 'creates a new activation and purges older ones' do
      result = described_class.activate(user: user, session_id: '123')

      expect(result)
        .to be_a(described_class)
        .and have_attributes(session_id: '123', user:)
      expect { session_activation.reload }
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'does not apply the Mastodon activation cap to a Rinspace-managed browser session' do
      result = described_class.activate(
        user:,
        session_id: 'managed-session',
        rinspace_parent_issuer: 'https://rinspace.example',
        rinspace_parent_uid: 'uid-7',
        rinspace_parent_sid: SecureRandom.uuid,
        rinspace_parent_version: 7,
        rinspace_parent_auth_time: Time.zone.now,
        rinspace_binding_id: SecureRandom.uuid
      )

      expect(result).to be_rinspace_managed
      expect(result.access_token).to have_attributes(
        rinspace_parent_issuer: result.rinspace_parent_issuer,
        rinspace_parent_uid: 'uid-7',
        rinspace_parent_sid: result.rinspace_parent_sid,
        rinspace_parent_version: 7
      )
      expect { session_activation.reload }.to_not raise_error
    end
  end

  describe '.deactivate' do
    context 'when id is absent' do
      let(:id) { nil }

      it 'returns nil' do
        expect(described_class.deactivate(id)).to be_nil
      end
    end

    context 'when id exists' do
      let!(:session_activation) { Fabricate(:session_activation) }

      it 'destroys the record' do
        described_class.deactivate(session_activation.session_id)

        expect { session_activation.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '.deactivate_rinspace_parent' do
    let(:user) { Fabricate(:user) }
    let(:issuer) { 'https://rinspace.example' }
    let(:sid_a) { SecureRandom.uuid }
    let(:sid_b) { SecureRandom.uuid }
    let!(:activation_a) do
      described_class.activate(user:, session_id: 'a', rinspace_parent_issuer: issuer, rinspace_parent_uid: 'uid-a', rinspace_parent_sid: sid_a, rinspace_parent_version: 3, rinspace_parent_auth_time: Time.zone.now, rinspace_binding_id: SecureRandom.uuid)
    end
    let!(:activation_b) do
      described_class.activate(user:, session_id: 'b', rinspace_parent_issuer: issuer, rinspace_parent_uid: 'uid-a', rinspace_parent_sid: sid_b, rinspace_parent_version: 2, rinspace_parent_auth_time: Time.zone.now, rinspace_binding_id: SecureRandom.uuid)
    end
    let!(:push_a) { Fabricate(:web_push_subscription, user:, access_token: activation_a.access_token, session_activation: activation_a) }

    it 'destroys only the matching activation, browser token, and push subscription' do
      token_a = activation_a.access_token
      token_b = activation_b.access_token

      described_class.deactivate_rinspace_parent(issuer:, sid: sid_a, version: 3)

      expect { activation_a.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { token_a.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { push_a.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { activation_b.reload }.to_not raise_error
      expect { token_b.reload }.to_not raise_error
    end

    it 'ignores a stale parent revocation version' do
      described_class.deactivate_rinspace_parent(issuer:, sid: sid_a, version: 2)

      expect { activation_a.reload }.to_not raise_error
    end
  end

  describe '.purge_old' do
    around do |example|
      before = Rails.configuration.x.max_session_activations
      Rails.configuration.x.max_session_activations = 1
      example.run
      Rails.configuration.x.max_session_activations = before
    end

    let!(:oldest_session_activation) { Fabricate(:session_activation, created_at: 10.days.ago) }
    let!(:newest_session_activation) { Fabricate(:session_activation, created_at: 5.days.ago) }

    it 'preserves the newest X records based on config' do
      described_class.purge_old

      expect { oldest_session_activation.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { newest_session_activation.reload }.to_not raise_error
    end
  end

  describe '.exclusive' do
    let!(:unwanted_session_activation) { Fabricate(:session_activation) }
    let!(:wanted_session_activation) { Fabricate(:session_activation) }

    it 'preserves supplied record and destroys all others' do
      described_class.exclusive(wanted_session_activation.session_id)

      expect { unwanted_session_activation.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { wanted_session_activation.reload }.to_not raise_error
    end
  end
end
