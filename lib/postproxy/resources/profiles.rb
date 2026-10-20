require "erb"

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

      # Per-day series. `attribution: "publish"` attributes post metrics to the
      # day the post was published instead of the day they were received.
      def daily_stats(id, placement_id: nil, from: nil, to: nil, attribution: nil, profile_group_id: nil)
        params = {}
        params[:placement_id] = placement_id if placement_id
        params[:from] = from if from
        params[:to] = to if to
        params[:attribution] = attribution if attribution

        result = @client.request(:get, "/profiles/#{id}/daily_stats",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
        DailyStatsResponse.new(data: result[:data])
      end

      def follower_history(id, placement_id: nil, from: nil, to: nil, profile_group_id: nil)
        params = {}
        params[:placement_id] = placement_id if placement_id
        params[:from] = from if from
        params[:to] = to if to

        result = @client.request(:get, "/profiles/#{id}/follower_history",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
        FollowerHistoryResponse.new(data: result[:data])
      end

      # Instagram only: whether a DM participant is verified and follows you.
      def participant_status(id, user_id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}/participants/#{ERB::Util.url_encode(user_id.to_s)}",
          profile_group_id: profile_group_id
        )
        ParticipantStatus.new(**result)
      end

      # LinkedIn only: resolve a company page URL (or vanity name) to the URN
      # used to @-mention it in a post.
      def resolve_mention(id, url, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}/resolve_mention",
          params: { url: url },
          profile_group_id: profile_group_id
        )
        ResolvedMention.new(**result)
      end

      # Music and original sounds an Instagram reel can attach via
      # `platforms.instagram.audio_id`. Profiles connected via Facebook login
      # only. `audio_type` is "music" or "original_sound". Returns the
      # response hash (`data` plus paging).
      def instagram_available_audio(id, audio_type: nil, search_query: nil, profile_group_id: nil)
        params = {}
        params[:audio_type] = audio_type if audio_type
        params[:search_query] = search_query if search_query

        @client.request(:get, "/profiles/#{id}/instagram/available_audio",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
      end

      # Facebook only. `page_id` is the placement id from #placements. Returns
      # the Page fields as a hash.
      def facebook_page(id, page_id, fields: nil, profile_group_id: nil)
        params = { page_id: page_id }
        params[:fields] = fields if fields

        @client.request(:get, "/profiles/#{id}/facebook/page", params: params, profile_group_id: profile_group_id)
      end

      # Update the Page's about / contact fields, e.g. `about` (255 characters
      # or fewer), `description`, `website`, `phone`, `emails`.
      def update_facebook_page(id, page_id, fields, profile_group_id: nil, idempotency_key: nil)
        @client.request(:patch, "/profiles/#{id}/facebook/update_page",
          json: fields.merge(page_id: page_id),
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
      end

      # Moves the profile (with its placements) to another profile group.
      def assign_to_group(id, target_profile_group_id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:patch, "/profiles/#{id}/assign_to_group",
          json: { target_profile_group_id: target_profile_group_id },
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Profile.new(**result)
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

      # Imports DM history back to `from`. Like #backfill_posts, runs in the
      # background and only one runs per profile.
      def backfill_chats(id, from:, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:post, "/profiles/#{id}/backfill_chats",
          json: { from: from },
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        ChatSync.new(**result)
      end

      def chat_syncs(id, trigger: nil, status: nil, page: nil, per_page: nil, profile_group_id: nil)
        params = {}
        params[:trigger] = trigger if trigger
        params[:status] = status if status
        params[:page] = page if page
        params[:per_page] = per_page if per_page

        result = @client.request(:get, "/profiles/#{id}/chat_syncs",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
        syncs = (result[:data] || []).map { |s| ChatSync.new(**s) }
        PaginatedResponse.new(
          data: syncs,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      def chat_sync(id, chat_sync_id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}/chat_syncs/#{chat_sync_id}",
          profile_group_id: profile_group_id
        )
        ChatSync.new(**result)
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
