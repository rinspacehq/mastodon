# frozen_string_literal: true

class OEmbedSerializer < ActiveModel::Serializer
  INLINE_STYLES = {
    blockquote: <<~CSS.squish,
      background: #FCF8FF;
      border-radius: 8px;
      border: 1px solid #C9C4DA;
      margin: 0;
      max-width: 540px;
      min-width: 270px;
      overflow: hidden;
      padding: 0;
    CSS
    status_link: <<~CSS.squish,
      align-items: center;
      color: #1C1A25;
      display: flex;
      flex-direction: column;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Oxygen, Ubuntu, Cantarell, 'Fira Sans', 'Droid Sans', 'Helvetica Neue', Roboto, sans-serif;
      font-size: 14px;
      justify-content: center;
      letter-spacing: 0.25px;
      line-height: 20px;
      padding: 24px;
      text-decoration: none;
    CSS
    div_account: <<~CSS.squish,
      color: #787588;
      margin-top: 16px;
    CSS
    div_view: <<~CSS.squish,
      font-weight: 500;
    CSS
  }.freeze

  DEFAULT_WIDTH = 400

  include RoutingHelper
  include ActionView::Helpers::TagHelper

  attributes :type, :version, :author_name,
             :author_url, :provider_name, :provider_url,
             :cache_age, :html, :width, :height

  def type
    'rich'
  end

  def version
    '1.0'
  end

  def author_name
    object.account.display_name.presence || object.account.username
  end

  def author_url
    short_account_url(object.account)
  end

  def provider_name
    return I18n.t('rinspace.metadata_name') if Mastodon::RinspaceLocalOnly.enabled?

    Rails.configuration.x.local_domain
  end

  def provider_url
    root_url
  end

  def cache_age
    86_400
  end

  def html
    <<~HTML.squish
      <blockquote class="mastodon-embed" style="#{INLINE_STYLES[:blockquote]}">
        <a href="#{ERB::Util.html_escape(status_url)}" target="_blank" rel="noopener noreferrer" style="#{INLINE_STYLES[:status_link]}">
          <img src="#{frontend_asset_url('images/rinspace-mark-128.png')}" width="32" height="32" alt="#{ERB::Util.html_escape(provider_name)}">
          <div style="#{INLINE_STYLES[:div_account]}">Post by #{ERB::Util.html_escape(account_address)}</div>
          <div style="#{INLINE_STYLES[:div_view]}">View on #{ERB::Util.html_escape(provider_name)}</div>
        </a>
      </blockquote>
    HTML
  end

  def width
    (instance_options[:width] || DEFAULT_WIDTH).to_i
  end

  def height
    instance_options[:height].presence&.to_i
  end

  private

  def status_url
    if Mastodon::RinspaceLocalOnly.enabled?
      return canonical_rinspace_status_url(object.id, Rinspace::StatusSlug.for(object))
    end

    ActivityPub::TagManager.instance.url_for(object)
  end

  def account_address
    address = "@#{object.account.pretty_acct}"
    return address unless object.account.local?

    "#{address}@#{Rails.configuration.x.local_domain}"
  end
end
