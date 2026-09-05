# frozen_string_literal: true

namespace :rinspace do
  namespace :local_only do
    desc 'Fail unless strict local-only configuration, data and queues have a zero federation baseline'
    task audit: :environment do
      require 'sidekiq/api'

      queued = Sidekiq::Queue.all.sum do |queue|
        queue.count { |job| Mastodon::RinspaceLocalOnly.blocked_worker?(job.klass) }
      end
      scheduled = Sidekiq::ScheduledSet.new.count { |job| Mastodon::RinspaceLocalOnly.blocked_worker?(job.klass) }
      retries = Sidekiq::RetrySet.new.count { |job| Mastodon::RinspaceLocalOnly.blocked_worker?(job.klass) }

      result = {
        enabled: Mastodon::RinspaceLocalOnly.enabled?,
        remote_accounts: Account.remote.count,
        remote_statuses: Status.remote.count,
        relays: Relay.count,
        fasp_providers: Fasp::Provider.count,
        blocked_jobs: queued + scheduled + retries,
      }

      puts result.to_json
      abort 'Rinspace local-only audit failed; public traffic must remain closed' unless result[:enabled] && result.except(:enabled).values.all?(&:zero?)
    end
  end
end
