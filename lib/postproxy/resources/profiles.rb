module PostProxy
  module Resources
    class Profiles
      def initialize(client)
        @client = client
      end

      def list(profile_group_id: nil)
        result = @client.request(:get, "/profiles", profile_group_id: profile_group_id)
        profiles = (result[:data] || []).map { |p| Profile.new(**p) }
        ListResponse.new(data: profiles)
      end

      def get(id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}", profile_group_id: profile_group_id)
        Profile.new(**result)
      end

      def placements(id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}/placements", profile_group_id: profile_group_id)
        items = (result[:data] || []).map { |p| Placement.new(**p) }
        ListResponse.new(data: items)
      end

      # `placement_id` is required for facebook, linkedin, and telegram profiles.
      def get_profile_stats(id, placement_id: nil, from: nil, to: nil, profile_group_id: nil)
        params = {}
        params[:placement_id] = placement_id if placement_id
        params[:from] = from if from
        params[:to] = to if to

        result = @client.request(:get, "/profiles/#{id}/stats",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
        ProfileStatsResponse.new(data: result[:data])
      end

      # Moves a placement (e.g. a Facebook Page or Telegram channel) to another
      # profile group. `placement_id` is the placement's external ID as
      # returned by #placements.
      def assign_placement_to_group(id, placement_id:, target_profile_group_id:, profile_group_id: nil,
        idempotency_key: nil)
        result = @client.request(:patch, "/profiles/#{id}/assign_placement_to_group",
          json: {
            placement_id: placement_id,
            target_profile_group_id: target_profile_group_id
          },
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Placement.new(**result)
      end

      # Imports older posts from the platform. Walks the profile's feed
      # backwards from the newest post until it reaches `from` or the platform
      # stops returning posts. Runs in the background — poll #post_sync with
      # the returned id for progress. Only one backfill runs per profile;
      # starting a second raises ConflictError carrying the running one's
      # `profile_sync_id`.
      def backfill_posts(id, from:, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:post, "/profiles/#{id}/backfill_posts",
          json: { from: from },
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        PostSync.new(**result)
      end

      # Lists post sync runs, newest first. Runs are kept for 30 days.
      def post_syncs(id, trigger: nil, status: nil, page: nil, per_page: nil, profile_group_id: nil)
        params = {}
        params[:trigger] = trigger if trigger
        params[:status] = status if status
        params[:page] = page if page
        params[:per_page] = per_page if per_page

        result = @client.request(:get, "/profiles/#{id}/post_syncs",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
        syncs = (result[:data] || []).map { |s| PostSync.new(**s) }
        PaginatedResponse.new(
          data: syncs,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      # Fetches a single run. Poll this to follow a backfill to completion —
      # the run is finished when `status` is "completed" or "failed".
      def post_sync(id, post_sync_id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}/post_syncs/#{post_sync_id}",
          profile_group_id: profile_group_id
        )
        PostSync.new(**result)
      end

      # Lists DM ice breakers. Supported for Instagram profiles only.
      def ice_breakers(id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}/ice_breakers", profile_group_id: profile_group_id)
        IceBreakersResponse.new(**result)
      end

      # Replaces the DM ice breakers for a profile (1-4 items).
      def set_ice_breakers(id, ice_breakers, profile_group_id: nil, idempotency_key: nil)
        items = ice_breakers.map { |ib| ib.is_a?(IceBreaker) ? ib.to_h : ib }
        result = @client.request(:post, "/profiles/#{id}/ice_breakers",
          json: { ice_breakers: items },
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        SuccessResponse.new(**result)
      end

      def delete_ice_breakers(id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:delete, "/profiles/#{id}/ice_breakers",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        SuccessResponse.new(**result)
      end

      def delete(id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:delete, "/profiles/#{id}",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        SuccessResponse.new(**result)
      end
    end
  end
end
