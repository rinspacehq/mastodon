# frozen_string_literal: true

class Mastodon::RinspaceLocalOnlySidekiqMiddleware
  def call(worker_class, job, _queue, *_args)
    name = job['class'].presence || worker_class.to_s
    if Mastodon::RinspaceLocalOnly.blocked_worker?(name)
      Mastodon::RinspaceLocalOnly.instrument(:queue, source: name)
      return nil
    end

    yield
  end
end
