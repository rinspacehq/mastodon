# frozen_string_literal: true

module Mastodon
  module Middleware
    class RinspaceLocalOnly
      RESPONSE = [
        404,
        {
          'Cache-Control' => 'no-store',
          'Content-Type' => 'application/json; charset=utf-8',
          'X-Rinspace-Local-Only' => 'blocked',
        },
        ['{"error":"not_found","code":"local_only.federation_disabled"}'],
      ].freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        path = env['PATH_INFO'].to_s
        return @app.call(env) unless Mastodon::RinspaceLocalOnly.blocked_inbound_request?(env)

        Mastodon::RinspaceLocalOnly.instrument(:inbound, source: env['REQUEST_METHOD'].to_s, target: path)
        [RESPONSE[0], RESPONSE[1].dup, RESPONSE[2].dup]
      end
    end
  end
end
