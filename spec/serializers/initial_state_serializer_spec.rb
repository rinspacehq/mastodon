# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InitialStateSerializer do
  subject(:serializer) { described_class.new(InitialStatePresenter.new(settings: {})) }

  describe '#rinspace_auth' do
    it 'exposes only the public CloudBase client and same-origin SSO preparation path' do
      ClimateControl.modify(
        RINSPACE_CLOUDBASE_ENV_ID: 'rinspace-production',
        ONE_CLICK_SSO_LOGIN: 'true',
        OMNIAUTH_ONLY: 'true'
      ) do
        allow(Devise).to receive(:omniauth_providers).and_return([:openid_connect])

        expect(serializer.send(:rinspace_auth)).to eq(
          client_id: 'rinspace-production',
          gateway: 'https://rinspace-production.api.tcloudbasegateway.com/auth/v1',
          sso_prepare_path: '/auth/rinspace'
        )
      end
    end

    it 'does not expose an incomplete authentication configuration' do
      ClimateControl.modify(RINSPACE_CLOUDBASE_ENV_ID: nil) do
        expect(serializer.send(:rinspace_auth)).to be_nil
      end
    end
  end
end
