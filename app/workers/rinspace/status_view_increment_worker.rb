# frozen_string_literal: true

class Rinspace::StatusViewIncrementWorker
  include Sidekiq::Worker

  sidekiq_options retry: 5

  def perform(status_id)
    return unless Status.kept.local.exists?(id: status_id)

    now = Time.current
    StatusStat.upsert(
      { status_id:, views_count: 1, created_at: now, updated_at: now },
      unique_by: :index_status_stats_on_status_id,
      on_duplicate: Arel.sql('views_count = status_stats.views_count + 1, updated_at = NOW()')
    )
  end
end
