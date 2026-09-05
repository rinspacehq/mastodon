# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace status permalinks' do
  let(:account) { Fabricate(:account) }
  let(:status) { Fabricate(:status, account:, text: 'A stable local post', visibility: :public) }
  let(:canonical_path) { "/p/#{status.id}/a-stable-local-post" }

  it 'temporarily normalizes the short URL to the current slug' do
    get "/p/#{status.id}"

    expect(response).to redirect_to(canonical_path)
    expect(response).to have_http_status(302)
  end

  it 'temporarily normalizes an incorrect slug using only the status ID' do
    get "/p/#{status.id}/definitely-wrong"

    expect(response).to redirect_to(canonical_path)
    expect(response).to have_http_status(302)
  end

  it 'renders the canonical URL and declares matching metadata' do
    get canonical_path

    expect(response).to have_http_status(200)
    expect(response.body).to include(status.text)
    canonical = Nokogiri::HTML(response.body).at_css('link[rel="canonical"]')
    expect(canonical&.[]('href')).to eq(canonical_rinspace_status_url(status.id, 'a-stable-local-post'))
  end

  it 'changes the readable slug after an edit without changing the stable ID' do
    status.update!(text: 'Edited words')

    get canonical_path

    expect(response).to redirect_to("/p/#{status.id}/edited-words")
  end

  it 'uses a non-sensitive fallback for sensitive and restricted posts' do
    sensitive = Fabricate(:status, account:, text: 'must not leak', sensitive: true, visibility: :public)

    get "/p/#{sensitive.id}/must-not-leak"

    expect(response).to redirect_to("/p/#{sensitive.id}/post")
  end

  it 'returns not found for an unknown stable ID' do
    get '/p/999999999999999999/post'

    expect(response).to have_http_status(404)
  end

  it 'does not resolve or redirect a legacy handle status URL' do
    get "/@#{account.username}/#{status.id}"

    expect(response).to have_http_status(404)
    expect(response).not_to be_redirect
  end

  it 'does not retain the legacy embed URL' do
    get "/@#{account.username}/#{status.id}/embed"

    expect(response).to have_http_status(404)
    expect(response).not_to be_redirect
  end

  it 'redirects a boost wrapper to the original status permalink' do
    boost = Fabricate(:status, account: Fabricate(:account), reblog: status)

    get "/p/#{boost.id}"

    expect(response).to redirect_to(canonical_rinspace_status_url(status.id, 'a-stable-local-post'))
  end
end
