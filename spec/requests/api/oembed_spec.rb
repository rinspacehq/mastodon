# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API OEmbed' do
  describe 'GET /api/oembed' do
    before { host! Rails.configuration.x.local_domain }

    context 'when status is public' do
      let(:status) { Fabricate(:status, visibility: :public) }

      it 'returns Rinspace-branded embed metadata with private cache control headers' do
        allow(Mastodon::RinspaceLocalOnly).to receive(:enabled?).and_return(true)

        get '/api/oembed', params: { url: short_account_status_url(status.account, status) }

        expect(response)
          .to have_http_status(200)
        expect(response.content_type)
          .to start_with('application/json')
        expect(response.headers['Cache-Control'])
          .to include('private, no-store')

        payload = response.parsed_body
        expect(payload['provider_name']).to eq('芥子环 (Rinspace)')
        expect(payload['html']).to include(canonical_rinspace_status_url(status.id, Rinspace::StatusSlug.for(status)))
        expect(payload['html']).to include('rinspace-mark-128')
        expect(payload['html']).not_to include('logo-symbol-icon')
      end
    end

    context 'when status is not public' do
      let(:status) { Fabricate(:status, visibility: :direct) }

      it 'returns not found' do
        get '/api/oembed', params: { url: short_account_status_url(status.account, status) }

        expect(response)
          .to have_http_status(404)
        expect(response.content_type)
          .to start_with('application/json')
      end
    end
  end
end
