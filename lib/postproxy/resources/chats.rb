module PostProxy
  module Resources
    class Chats
      def initialize(client)
        @client = client
      end

      def list(profile_id, page: nil, per_page: nil, before: nil, after: nil, profile_group_id: nil)
        params = {}
        params[:page] = page if page
        params[:per_page] = per_page if per_page
        params[:before] = format_time(before) if before
        params[:after] = format_time(after) if after

        result = @client.request(:get, "/profiles/#{profile_id}/chats", params: params, profile_group_id: profile_group_id)
        chats = (result[:data] || []).map { |c| Chat.new(**c) }
        PaginatedResponse.new(
          data: chats,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      def create(profile_id, participant_external_id, participant_username: nil, participant_name: nil, profile_group_id: nil)
        json_body = { participant_external_id: participant_external_id }
        json_body[:participant_username] = participant_username if participant_username
        json_body[:participant_name] = participant_name if participant_name

        result = @client.request(:post, "/profiles/#{profile_id}/chats", json: json_body, profile_group_id: profile_group_id)
        Chat.new(**result)
      end

      def get(chat_id, profile_group_id: nil)
        result = @client.request(:get, "/chats/#{chat_id}", profile_group_id: profile_group_id)
        Chat.new(**result)
      end

      def archive(chat_id, profile_group_id: nil)
        result = @client.request(:post, "/chats/#{chat_id}/archive", profile_group_id: profile_group_id)
        Chat.new(**result)
      end

      def unarchive(chat_id, profile_group_id: nil)
        result = @client.request(:delete, "/chats/#{chat_id}/archive", profile_group_id: profile_group_id)
        Chat.new(**result)
      end

      private

      def format_time(value)
        return value if value.is_a?(String)
        value.iso8601
      end
    end
  end
end
