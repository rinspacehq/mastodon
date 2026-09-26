# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rinspace sitemaps' do
  let(:account) { Fabricate(:account) }

  def approved_status(**attributes)
    Fabricate(:status, account:, visibility: :public, rinspace_review_state: 'approved', **attributes)
  end

  around do |example|
    ClimateControl.modify RINSPACE_TWEET_SITEMAP_ENABLED: 'true' do
      example.run
    end
  end

  it 'publishes eligible originals and replies in stable descending ID order' do
    older = approved_status(text: 'Older tweet')
    parent = approved_status(text: 'Parent')
    reply = approved_status(text: 'Public reply', reply: true, in_reply_to_id: parent.id)
    Fabricate(:status, account:, reblog: older, visibility: :public, rinspace_review_state: 'approved')
    approved_status(text: 'Unlisted tweet', visibility: :unlisted)

    get '/sitemap-tweets.xml'

    expect(response).to have_http_status(200)
    expect(response.media_type).to eq('application/xml')
    document = Nokogiri::XML(response.body)
    locations = document.xpath('//*[local-name()="loc"]').map(&:text)
    expect(locations).to include(canonical_rinspace_status_url(older.id, 'older-tweet'))
    expect(locations).to include(canonical_rinspace_status_url(reply.id, 'public-reply'))
    expect(locations.join(' ')).not_to include('unlisted-tweet')
    expect(locations).to eq(locations.sort_by { |url| -url.split('/')[4].to_i })
    expect(document.xpath('//*[local-name()="lastmod"]').length).to eq(locations.length)
  end

  it 'reflects external noindex preference and moderation on the next request' do
    status = approved_status(text: 'Preference controlled')

    get '/sitemap-tweets.xml'
    expect(response.body).to include("/p/#{status.id}/preference-controlled")

    account.user.settings.update('noindex' => true)
    account.user.save!
    get '/sitemap-tweets.xml'
    expect(response.body).not_to include("/p/#{status.id}/")

    account.user.settings.update('noindex' => false)
    account.user.save!
    status.update!(rinspace_review_state: 'removed')
    get '/sitemap-tweets.xml'
    expect(response.body).not_to include("/p/#{status.id}/")
  end

  it 'fails instead of silently truncating a section at the promotion threshold' do
    allow(Rinspace::SearchIndexEligibility).to receive(:sitemap_entries).and_return(
      Array.new(Rinspace::SitemapsController::PROMOTION_THRESHOLD + 1) do |index|
        Rinspace::SearchIndexEligibility::SitemapEntry.new(status_id: index + 1, url: "https://rinspace.test/p/#{index + 1}/tweet", last_modified_at: Time.current)
      end
    )

    get '/sitemap-tweets.xml'

    expect(response).to have_http_status(503)
    expect(response.headers['Retry-After']).to eq('300')
    expect(response.body).to be_empty
  end
end
