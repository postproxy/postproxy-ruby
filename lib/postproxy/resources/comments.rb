module PostProxy
  module Resources
    class Comments
      def initialize(client)
        @client = client
      end

      # `from` and `to` filter on when PostProxy received the comment
      # (`created_at`), not the platform's `posted_at`. They apply to top-level
      # comments — one in range brings its full `replies` array with it.
      def list(post_id, profile_id:, page: nil, per_page: nil, from: nil, to: nil)
        params = { profile_id: profile_id }
        params[:page] = page if page
        params[:per_page] = per_page if per_page
        params[:from] = from if from
        params[:to] = to if to

        result = @client.request(:get, "/posts/#{post_id}/comments", params: params)
        comments = (result[:data] || []).map { |c| Comment.new(**c) }
        PaginatedResponse.new(
          data: comments,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      # Comments across every post in the profile group. Flat: replies come
      # back as their own entries linked by `parent_external_id`, so `total`
      # counts every comment. `profiles` takes profile IDs or network names,
      # mixed.
      def list_all(post_ids: nil, profiles: nil, from: nil, to: nil, page: nil, per_page: nil,
        profile_group_id: nil)
        params = {}
        params[:post_ids] = Array(post_ids).join(",") if post_ids
        params[:profiles] = Array(profiles).join(",") if profiles
        params[:from] = from if from
        params[:to] = to if to
        params[:page] = page if page
        params[:per_page] = per_page if per_page

        result = @client.request(:get, "/comments",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
        comments = (result[:data] || []).map { |c| BulkComment.new(**c) }
        PaginatedResponse.new(
          data: comments,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      def get(post_id, comment_id, profile_id:)
        result = @client.request(:get, "/posts/#{post_id}/comments/#{comment_id}", params: { profile_id: profile_id })
        Comment.new(**result)
      end

      def create(post_id, text, profile_id:, parent_id: nil, idempotency_key: nil)
        json_body = { text: text }
        json_body[:parent_id] = parent_id if parent_id

        result = @client.request(:post, "/posts/#{post_id}/comments",
          params: { profile_id: profile_id },
          json: json_body,
          idempotency_key: idempotency_key
        )
        Comment.new(**result)
      end

      def delete(post_id, comment_id, profile_id:, idempotency_key: nil)
        result = @client.request(:delete, "/posts/#{post_id}/comments/#{comment_id}",
          params: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      def hide(post_id, comment_id, profile_id:, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/hide",
          params: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      def unhide(post_id, comment_id, profile_id:, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/unhide",
          params: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      def like(post_id, comment_id, profile_id:, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/like",
          params: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      def unlike(post_id, comment_id, profile_id:, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/unlike",
          params: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      def private_reply(post_id, comment_id, profile_id:, text:, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/private_reply",
          params: { profile_id: profile_id },
          json: { text: text },
          idempotency_key: idempotency_key
        )
        Message.new(**result)
      end
    end
  end
end
