# frozen_string_literal: true

namespace :rinspace do
  namespace :search do
    desc 'Print aggregate, privacy-safe external search health as JSON'
    task health: :environment do
      eligible = 0
      Rinspace::SearchIndexEligibility.candidates.find_in_batches(batch_size: 500) do |statuses|
        eligible += statuses.count { |status| Rinspace::SearchIndexEligibility.eligible?(status) }
      end
      outbox = RinspaceSearchEventOutbox
        .group(:delivery_state, :last_error_code)
        .pluck(:delivery_state, :last_error_code, Arel.sql('COUNT(*)'), Arel.sql("COALESCE(EXTRACT(EPOCH FROM NOW()-MIN(occurred_at)),0)::bigint"))
        .map { |state, code, count, age| { state:, errorCode: code, count:, oldestAgeSeconds: age } }
      puts JSON.generate(
        externallyIndexableTweets: eligible,
        sitemapCapacityState: eligible >= Rinspace::SitemapsController::PROMOTION_THRESHOLD ? 'promote_to_shards' : 'ok',
        delivery: outbox
      )
    end
  end
end
