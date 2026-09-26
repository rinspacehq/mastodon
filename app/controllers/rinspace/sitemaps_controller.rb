# frozen_string_literal: true

class Rinspace::SitemapsController < ApplicationController
  PROMOTION_THRESHOLD = 45_000

  def tweets
    return head :not_found unless ENV['RINSPACE_TWEET_SITEMAP_ENABLED'] == 'true'

    entries = Rinspace::SearchIndexEligibility.sitemap_entries(limit: PROMOTION_THRESHOLD + 1)
    if entries.length > PROMOTION_THRESHOLD
      response.headers['Retry-After'] = '300'
      return head :service_unavailable
    end

    xml = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |builder|
      builder.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9') do
        entries.each do |entry|
          builder.url do
            builder.loc(entry.url)
            builder.lastmod(entry.last_modified_at.utc.iso8601)
          end
        end
      end
    end.to_xml

    expires_in 5.minutes, public: true
    render body: xml, content_type: 'application/xml'
  rescue ActiveRecord::ActiveRecordError
    response.headers['Retry-After'] = '60'
    head :service_unavailable
  end
end
