module PostProxy
  module Resources
    # Account-wide API keys only — placements span profile groups.
    class Placements
      def initialize(client)
        @client = client
      end

      def list(page: nil, per_page: nil)
        params = {}
        params[:page] = page if page
        params[:per_page] = per_page if per_page

        result = @client.request(:get, "/placements", params: params.empty? ? nil : params)
        placements = (result[:data] || []).map { |p| AccountPlacement.new(**p) }
        PaginatedResponse.new(
          data: placements,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      # When the same placement is reachable through several connected
      # profiles, choose which one PostProxy posts and reads through.
      def set_active_profile(id, profile_id, idempotency_key: nil)
        result = @client.request(:patch, "/placements/#{id}/set_active_profile",
          json: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AccountPlacement.new(**result)
      end
    end
  end
end
