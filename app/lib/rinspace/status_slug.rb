# frozen_string_literal: true

module Rinspace
  class StatusSlug
    VERSION = 'rinspace-status-slug-v1'
    FALLBACK = 'post'
    MAX_GRAPHEMES = 48
    PUBLIC_VISIBILITIES = %w(public unlisted).freeze

    class << self
      def for(status)
        status = status.reblog if status.reblog?
        call(text: status.text, visibility: status.visibility, sensitive: status.sensitive?)
      end

      def call(text:, visibility:, sensitive:)
        return FALLBACK if sensitive || !PUBLIC_VISIBILITIES.include?(visibility.to_s)

        slug = text.to_s
          .unicode_normalize(:nfkc)
          .gsub(/<[^>]*>/u, ' ')
          .gsub(%r{https?://[^\s<]+}iu, ' ')
          .gsub(/[\p{L}\p{N}._%+\-]+@[\p{L}\p{N}.\-]+\.[\p{L}]{2,}/u, ' ')
          .gsub(/(^|[\s(\[{])@[\p{L}\p{N}_]+(?:@[\p{L}\p{N}.\-]+)?/u, '\1')
          .gsub(/[[:cntrl:]\p{Cf}]/u, ' ')
          .downcase
          .gsub(/[^\p{L}\p{M}\p{N}]+/u, '-')
          .gsub(/\A-+|-+\z/u, '')
          .each_grapheme_cluster
          .first(MAX_GRAPHEMES)
          .join
          .sub(/-+\z/u, '')

        slug.empty? ? FALLBACK : slug
      end
    end
  end
end
