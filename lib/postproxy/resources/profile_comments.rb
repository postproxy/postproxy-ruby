module PostProxy
  module Resources
    class ProfileComments
      def initialize(client)
        @client = client
      end

      def list(profile_id, placement_id: nil, page: nil, per_page: nil)
        params = {}
        params[:placement_id] = placement_id if placement_id
        params[:page] = page if page
        params[:per_page] = per_page if per_page

        result = @client.request(:get, "/profiles/#{profile_id}/comments", params: params)
        comments = (result[:data] || []).map { |c| ProfileComment.new(**c) }
        PaginatedResponse.new(
          data: comments,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      def get(profile_id, comment_id)
        result = @client.request(:get, "/profiles/#{profile_id}/comments/#{comment_id}")
        ProfileComment.new(**result)
      end

      def create(profile_id, parent_id:, text:, idempotency_key: nil)
        result = @client.request(:post, "/profiles/#{profile_id}/comments",
                                 json: { parent_id: parent_id, text: text },
                                 idempotency_key: idempotency_key)
        ProfileComment.new(**result)
      end

      def delete(profile_id, comment_id, idempotency_key: nil)
        result = @client.request(:delete, "/profiles/#{profile_id}/comments/#{comment_id}",
                                 idempotency_key: idempotency_key)
        AcceptedResponse.new(**result)
      end
    end
  end
end
