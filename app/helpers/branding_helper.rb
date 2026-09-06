# frozen_string_literal: true

module BrandingHelper
  def rinspace_brand_name
    I18n.t('rinspace.brand_name', default: site_title)
  end

  def logo_as_symbol(version = :icon)
    case version
    when :icon
      _logo_as_symbol_icon
    when :wordmark
      _logo_as_symbol_wordmark
    end
  end

  def _logo_as_symbol_wordmark
    tag.span(class: 'logo logo--wordmark rinspace-wordmark', role: 'img', 'aria-label': rinspace_brand_name) do
      image_tag(frontend_asset_path('images/rinspace-mark-128.png'), alt: '', aria: { hidden: true }) +
        tag.span(rinspace_brand_name)
    end
  end

  def _logo_as_symbol_icon
    image_tag(frontend_asset_path('images/rinspace-mark-128.png'), alt: rinspace_brand_name, class: 'logo logo--icon')
  end

  def render_logo
    image_tag(frontend_asset_path('images/rinspace-mark-128.png'), alt: rinspace_brand_name, class: 'logo logo--icon')
  end
end
