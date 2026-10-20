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
      # mixed. `placement_id` narrows to one page / organization.
      def list_all(post_ids: nil, profiles: nil, placement_id: nil, from: nil, to: nil, page: nil, per_page: nil,
        profile_group_id: nil)
        params = {}
        params[:post_ids] = Array(post_ids).join(",") if post_ids
        params[:profiles] = Array(profiles).join(",") if profiles
        params[:placement_id] = placement_id if placement_id
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

      # Edit a comment you published. Facebook and YouTube only. Runs in the
      # background — the outcome arrives as `comment.edited` /
      # `comment.edit_failed`.
      def edit(post_id, comment_id, text, profile_id:, idempotency_key: nil)
        result = @client.request(:patch, "/posts/#{post_id}/comments/#{comment_id}",
          params: { profile_id: profile_id },
          json: { body: text },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
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

      # TikTok only.
      def pin(post_id, comment_id, profile_id:, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/pin",
          params: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      def unpin(post_id, comment_id, profile_id:, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/unpin",
          params: { profile_id: profile_id },
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      # Sends a DM to the comment's author (Instagram/Facebook) and returns a
      # Message. One private reply per comment, within 7 days of it.
      # `quick_replies`, `buttons`, `card` and `elements` work as in
      # Messages#send_message (model instances or plain hashes); `text` may be
      # empty when sending `elements`.
      def private_reply(post_id, comment_id, profile_id:, text:, quick_replies: nil, buttons: nil, card: nil,
        elements: nil, idempotency_key: nil)
        json_body = { text: text }
        json_body[:quick_replies] = quick_replies.map { |q| serialize_interactive(q) } if quick_replies
        json_body[:buttons] = buttons.map { |b| serialize_interactive(b) } if buttons
        json_body[:card] = serialize_interactive(card) if card
        json_body[:elements] = elements.map { |e| serialize_interactive(e) } if elements

        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/private_reply",
          params: { profile_id: profile_id },
          json: json_body,
          idempotency_key: idempotency_key
        )
        Message.new(**result)
      end

      private

      def serialize_interactive(value)
        value.respond_to?(:to_h) && !value.is_a?(Hash) ? value.to_h : value
      end
    end
  end
end
