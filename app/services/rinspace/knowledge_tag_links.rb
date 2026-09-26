# frozen_string_literal: true

module Rinspace
  class KnowledgeTagLinks
    Link = Data.define(:id, :name, :url)
    LIMIT = 8

    def self.for(status, limit: LIMIT)
      return [] if status.nil?

      origin = ENV.fetch('RINSPACE_OUTER_ORIGIN', 'https://rinspace.com').to_s.chomp('/')
      RinspaceTagBinding
        .where(tag_id: status.tag_ids, state: 'verified')
        .order(:rinspace_tag_id)
        .limit(limit)
        .map do |binding|
          slug = ERB::Util.url_encode(binding.canonical_name)
          Link.new(id: binding.rinspace_tag_id.to_s, name: binding.canonical_name, url: "#{origin}/tags/#{binding.rinspace_tag_id}/#{slug}")
        end
    end
  end
end
