module PostProxy
  module Resources
    class Comments
      def initialize(client)
        @client = client
      end

      def list(post_id, profile_id:, page: nil, per_page: nil)
        params = { profile_id: profile_id }
        params[:page] = page if page
        params[:per_page] = per_page if per_page

        result = @client.request(:get, "/posts/#{post_id}/comments", params: params)
        comments = (result[:data] || []).map { |c| Comment.new(**c) }
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

      def create(post_id, text, profile_id:, parent_id: nil)
        json_body = { text: text }
        json_body[:parent_id] = parent_id if parent_id

        result = @client.request(:post, "/posts/#{post_id}/comments", params: { profile_id: profile_id }, json: json_body)
        Comment.new(**result)
      end

      def delete(post_id, comment_id, profile_id:)
        result = @client.request(:delete, "/posts/#{post_id}/comments/#{comment_id}", params: { profile_id: profile_id })
        AcceptedResponse.new(**result)
      end

      def hide(post_id, comment_id, profile_id:)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/hide", params: { profile_id: profile_id })
        AcceptedResponse.new(**result)
      end

      def unhide(post_id, comment_id, profile_id:)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/unhide", params: { profile_id: profile_id })
        AcceptedResponse.new(**result)
      end

      def like(post_id, comment_id, profile_id:)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/like", params: { profile_id: profile_id })
        AcceptedResponse.new(**result)
      end

      def unlike(post_id, comment_id, profile_id:)
        result = @client.request(:post, "/posts/#{post_id}/comments/#{comment_id}/unlike", params: { profile_id: profile_id })
        AcceptedResponse.new(**result)
      end
    end
  end
end
