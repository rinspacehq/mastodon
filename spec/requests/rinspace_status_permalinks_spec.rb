# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace status permalinks' do
  let(:account) { Fabricate(:account) }
  let(:status) { Fabricate(:status, account:, text: 'A stable local post', visibility: :public, rinspace_review_state: 'approved') }
  let(:canonical_path) { "/p/#{status.id}/a-stable-local-post" }

  before do
    entry = Vite::Manifest::Entrypoint.new('test-entry.js', nil, [], [])
    allow(Vite.manifest).to receive(:fetch!).and_return(entry)
    allow(Vite.manifest).to receive(:fetch)
    allow(Vite.manifest).to receive(:imports_for).and_return([])
    allow(Vite.manifest).to receive(:stylesheets_for).and_return([])
  end

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
    document = Nokogiri::HTML(response.body)
    canonical = document.at_css('link[rel="canonical"]')
    expect(canonical&.[]('href')).to eq(canonical_rinspace_status_url(status.id, 'a-stable-local-post'))
    expect(document.css('link[rel="canonical"]').length).to eq(1)
    expect(document.at_css('meta[property="og:url"]')&.[]('content')).to eq(canonical_rinspace_status_url(status.id, 'a-stable-local-post'))
    schema = JSON.parse(document.at_css('script[type="application/ld+json"]')&.text)
    expect(schema['url']).to eq(canonical_rinspace_status_url(status.id, 'a-stable-local-post'))
    expect(schema['dateModified']).to be_nil
    expect(document.at_css('main[data-rin-public-document="tweet"][data-rin-object-id] h1')).to be_present
  end

  it 'uses edited_at as the semantic modification time' do
    status.update!(text: 'Edited words', edited_at: 1.hour.from_now)

    get "/p/#{status.id}/edited-words"

    schema = JSON.parse(Nokogiri::HTML(response.body).at_css('script[type="application/ld+json"]').text)
    expect(schema['dateModified']).to eq(status.edited_at.iso8601)
  end

  it 'emits noindex without eligible structured data when the author opts out' do
    account.user.settings.update('noindex' => true)
    account.user.save!

    get canonical_path

    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(200)
    expect(document.at_css('meta[name="robots"]')&.[]('content')).to eq('noindex, noarchive')
    expect(document.at_css('script[type="application/ld+json"]')).to be_nil
    expect(document.css('link[rel="canonical"]').length).to eq(1)
  end

  it 'keeps eligible public replies in the same metadata contract' do
    parent = Fabricate(:status, account:, visibility: :public, rinspace_review_state: 'approved')
    reply = Fabricate(:status, account:, text: 'Public reply', visibility: :public, reply: true, in_reply_to_id: parent.id, rinspace_review_state: 'approved')

    get canonical_rinspace_status_path(reply.id, 'public-reply')

    expect(response).to have_http_status(200)
    expect(Nokogiri::HTML(response.body).at_css('script[type="application/ld+json"]')).to be_present
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
