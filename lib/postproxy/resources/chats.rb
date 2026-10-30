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

      # `placement_id` is required for WhatsApp: the phone number id from
      # `profiles.placements`.
      def create(profile_id, participant_external_id, participant_username: nil, participant_name: nil,
        placement_id: nil, profile_group_id: nil, idempotency_key: nil)
        json_body = { participant_external_id: participant_external_id }
        json_body[:participant_username] = participant_username if participant_username
        json_body[:participant_name] = participant_name if participant_name
        json_body[:placement_id] = placement_id if placement_id

        result = @client.request(:post, "/profiles/#{profile_id}/chats",
          json: json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Chat.new(**result)
      end

      def get(chat_id, profile_group_id: nil)
        result = @client.request(:get, "/chats/#{chat_id}", profile_group_id: profile_group_id)
        Chat.new(**result)
      end

      def archive(chat_id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:post, "/chats/#{chat_id}/archive",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Chat.new(**result)
      end

      def unarchive(chat_id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:delete, "/chats/#{chat_id}/archive",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Chat.new(**result)
      end

      # Mark the latest inbound message as read (shows the read receipt).
      def mark_read(chat_id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:post, "/chats/#{chat_id}/mark_read",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Chat.new(**result)
      end

      # Typing indicator. Facebook, Instagram and WhatsApp only.
      def start_typing(chat_id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:post, "/chats/#{chat_id}/start_typing",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      def stop_typing(chat_id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:post, "/chats/#{chat_id}/stop_typing",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        AcceptedResponse.new(**result)
      end

      # --- Thread control (Facebook & Instagram) ---
      #
      # Meta gives one app at a time control of a conversation when several
      # share a Page or Instagram inbox. These return the chat, whose
      # `metadata[:thread_control]` holds the owner Meta reports back.

      # Hand the conversation to another Meta app, e.g. Page Inbox
      # `263902037430900` or Instagram Inbox `1217981644879628`.
      def pass_thread_control(chat_id, target_app_id:, metadata: nil, profile_group_id: nil, idempotency_key: nil)
        thread_control(chat_id, "pass_thread_control", { target_app_id: target_app_id },
          metadata, profile_group_id, idempotency_key)
      end

      # Take the conversation from whichever app holds it. Needs Conversation
      # Routing; Instagram must be connected via Facebook.
      def take_thread_control(chat_id, metadata: nil, profile_group_id: nil, idempotency_key: nil)
        thread_control(chat_id, "take_thread_control", {}, metadata, profile_group_id, idempotency_key)
      end

      # Give up control; the conversation goes idle.
      def release_thread_control(chat_id, metadata: nil, profile_group_id: nil, idempotency_key: nil)
        thread_control(chat_id, "release_thread_control", {}, metadata, profile_group_id, idempotency_key)
      end

      # Ask the current owner to pass the conversation. Nothing changes until
      # it does — watch for `chat.thread_control_changed`.
      def request_thread_control(chat_id, metadata: nil, profile_group_id: nil, idempotency_key: nil)
        thread_control(chat_id, "request_thread_control", {}, metadata, profile_group_id, idempotency_key)
      end

      # Ask Meta who controls the conversation right now.
      def thread_owner(chat_id, profile_group_id: nil)
        result = @client.request(:get, "/chats/#{chat_id}/thread_owner", profile_group_id: profile_group_id)
        ThreadOwner.new(**result)
      end

      private

      def thread_control(chat_id, action, json_body, metadata, profile_group_id, idempotency_key)
        json_body[:metadata] = metadata unless metadata.nil?
        result = @client.request(:post, "/chats/#{chat_id}/#{action}",
          json: json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Chat.new(**result)
      end

      def format_time(value)
        return value if value.is_a?(String)
        value.iso8601
      end
    end
  end
end
