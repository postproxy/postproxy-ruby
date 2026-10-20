module PostProxy
  module Resources
    # WhatsApp number administration: registration, business profile, display
    # name, username, blocked users, groups and conversion events. Responses
    # are Meta's payloads, returned as plain hashes.
    #
    # `phone_number_id` is the placement id from
    # `profiles.placements(profile_id)`. Dataset and conversion calls are
    # account-level and don't take one.
    class WhatsApp
      def initialize(client)
        @client = client
      end

      # --- Phone number ---

      def number_info(profile_id, phone_number_id, profile_group_id: nil)
        call(:get, profile_id, "number_info", { phone_number_id: phone_number_id }, profile_group_id)
      end

      # `pin` is the 6-digit two-step verification PIN.
      def register_phone_number(profile_id, phone_number_id, pin, profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "register_phone_number",
          { phone_number_id: phone_number_id, pin: pin }, profile_group_id, idempotency_key)
      end

      # `method` is "SMS" or "VOICE".
      def request_verification_code(profile_id, phone_number_id, method: nil, language: nil, profile_group_id: nil,
        idempotency_key: nil)
        call(:post, profile_id, "request_verification_code",
          { phone_number_id: phone_number_id, method: method, language: language }, profile_group_id, idempotency_key)
      end

      def verify_phone_number(profile_id, phone_number_id, code, profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "verify_phone_number",
          { phone_number_id: phone_number_id, code: code }, profile_group_id, idempotency_key)
      end

      # --- Business profile ---

      def business_profile(profile_id, phone_number_id, profile_group_id: nil)
        call(:get, profile_id, "business_profile", { phone_number_id: phone_number_id }, profile_group_id)
      end

      def update_business_profile(profile_id, phone_number_id, about: nil, address: nil, description: nil,
        email: nil, websites: nil, vertical: nil, profile_group_id: nil, idempotency_key: nil)
        call(:patch, profile_id, "update_business_profile", {
          phone_number_id: phone_number_id,
          about: about,
          address: address,
          description: description,
          email: email,
          websites: websites,
          vertical: vertical
        }, profile_group_id, idempotency_key)
      end

      # Pass a public `url`, or base64 `data` with its `content_type`
      # (image/jpeg or image/png).
      def update_business_profile_photo(profile_id, phone_number_id, url: nil, data: nil, content_type: nil,
        profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "update_business_profile_photo", {
          phone_number_id: phone_number_id,
          url: url,
          data: data,
          content_type: content_type
        }, profile_group_id, idempotency_key)
      end

      # --- Display name ---

      def display_name(profile_id, phone_number_id, profile_group_id: nil)
        call(:get, profile_id, "display_name", { phone_number_id: phone_number_id }, profile_group_id)
      end

      # Meta reviews the new name; the outcome arrives as the
      # `placement.name_status_updated` webhook.
      def request_display_name_change(profile_id, phone_number_id, display_name, profile_group_id: nil,
        idempotency_key: nil)
        call(:post, profile_id, "request_display_name_change",
          { phone_number_id: phone_number_id, display_name: display_name }, profile_group_id, idempotency_key)
      end

      # --- Username ---

      def username(profile_id, phone_number_id, profile_group_id: nil)
        call(:get, profile_id, "username", { phone_number_id: phone_number_id }, profile_group_id)
      end

      # `transfer_action` is "none" or "force_transfer".
      def set_username(profile_id, phone_number_id, username, transfer_action: nil, profile_group_id: nil,
        idempotency_key: nil)
        call(:put, profile_id, "set_username",
          { phone_number_id: phone_number_id, username: username, transfer_action: transfer_action },
          profile_group_id, idempotency_key)
      end

      def delete_username(profile_id, phone_number_id, profile_group_id: nil, idempotency_key: nil)
        call(:delete, profile_id, "delete_username", { phone_number_id: phone_number_id }, profile_group_id,
          idempotency_key)
      end

      def username_suggestions(profile_id, phone_number_id, profile_group_id: nil)
        call(:get, profile_id, "username_suggestions", { phone_number_id: phone_number_id }, profile_group_id)
      end

      # --- Blocked users ---

      def blocked_users(profile_id, phone_number_id, limit: nil, after: nil, profile_group_id: nil)
        call(:get, profile_id, "blocked_users",
          { phone_number_id: phone_number_id, limit: limit, after: after }, profile_group_id)
      end

      def blocked_user_status(profile_id, phone_number_id, user, profile_group_id: nil)
        call(:get, profile_id, "blocked_user_status", { phone_number_id: phone_number_id, user: user },
          profile_group_id)
      end

      # `users` are phone numbers or WhatsApp ids.
      def block_users(profile_id, phone_number_id, users, profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "block_users", { phone_number_id: phone_number_id, users: users },
          profile_group_id, idempotency_key)
      end

      def unblock_users(profile_id, phone_number_id, users, profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "unblock_users", { phone_number_id: phone_number_id, users: users },
          profile_group_id, idempotency_key)
      end

      # --- Groups ---

      def groups(profile_id, phone_number_id, limit: nil, after: nil, profile_group_id: nil)
        call(:get, profile_id, "groups", { phone_number_id: phone_number_id, limit: limit, after: after },
          profile_group_id)
      end

      # `join_approval_mode` is "approval_required" or "auto_approve".
      def create_group(profile_id, phone_number_id, subject, description: nil, join_approval_mode: nil,
        profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "create_group", {
          phone_number_id: phone_number_id,
          subject: subject,
          description: description,
          join_approval_mode: join_approval_mode
        }, profile_group_id, idempotency_key)
      end

      def group(profile_id, phone_number_id, group_id, profile_group_id: nil)
        call(:get, profile_id, "group", { phone_number_id: phone_number_id, group_id: group_id }, profile_group_id)
      end

      def update_group(profile_id, phone_number_id, group_id, subject: nil, description: nil,
        join_approval_mode: nil, profile_group_id: nil, idempotency_key: nil)
        call(:patch, profile_id, "update_group", {
          phone_number_id: phone_number_id,
          group_id: group_id,
          subject: subject,
          description: description,
          join_approval_mode: join_approval_mode
        }, profile_group_id, idempotency_key)
      end

      def delete_group(profile_id, phone_number_id, group_id, profile_group_id: nil, idempotency_key: nil)
        call(:delete, profile_id, "delete_group", { phone_number_id: phone_number_id, group_id: group_id },
          profile_group_id, idempotency_key)
      end

      def add_group_participants(profile_id, phone_number_id, group_id, phone_numbers, profile_group_id: nil,
        idempotency_key: nil)
        group_members(:post, profile_id, "add_group_participants", phone_number_id, group_id, phone_numbers,
          profile_group_id, idempotency_key)
      end

      def remove_group_participants(profile_id, phone_number_id, group_id, phone_numbers, profile_group_id: nil,
        idempotency_key: nil)
        group_members(:post, profile_id, "remove_group_participants", phone_number_id, group_id, phone_numbers,
          profile_group_id, idempotency_key)
      end

      def create_group_invite_link(profile_id, phone_number_id, group_id, profile_group_id: nil,
        idempotency_key: nil)
        call(:post, profile_id, "create_group_invite_link",
          { phone_number_id: phone_number_id, group_id: group_id }, profile_group_id, idempotency_key)
      end

      def group_join_requests(profile_id, phone_number_id, group_id, profile_group_id: nil)
        call(:get, profile_id, "group_join_requests", { phone_number_id: phone_number_id, group_id: group_id },
          profile_group_id)
      end

      def approve_group_join_requests(profile_id, phone_number_id, group_id, phone_numbers, profile_group_id: nil,
        idempotency_key: nil)
        group_members(:post, profile_id, "approve_group_join_requests", phone_number_id, group_id, phone_numbers,
          profile_group_id, idempotency_key)
      end

      def reject_group_join_requests(profile_id, phone_number_id, group_id, phone_numbers, profile_group_id: nil,
        idempotency_key: nil)
        group_members(:post, profile_id, "reject_group_join_requests", phone_number_id, group_id, phone_numbers,
          profile_group_id, idempotency_key)
      end

      # --- Conversions (account-level) ---

      def dataset(profile_id, profile_group_id: nil)
        call(:get, profile_id, "dataset", {}, profile_group_id)
      end

      def create_dataset(profile_id, profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "create_dataset", {}, profile_group_id, idempotency_key)
      end

      # Report a conversion (e.g. Purchase, LeadSubmitted) back to Meta for a
      # click-to-WhatsApp ad. Identify the person by `chat_id` or `phone`.
      def send_conversion_event(profile_id, event_name:, event_id:, chat_id: nil, phone: nil, dataset_id: nil,
        event_time: nil, email: nil, external_id: nil, currency: nil, value: nil, content_ids: nil,
        test_code: nil, profile_group_id: nil, idempotency_key: nil)
        call(:post, profile_id, "send_conversion_event", {
          event_name: event_name,
          event_id: event_id,
          chat_id: chat_id,
          phone: phone,
          dataset_id: dataset_id,
          event_time: event_time,
          email: email,
          external_id: external_id,
          currency: currency,
          value: value,
          content_ids: content_ids,
          test_code: test_code
        }, profile_group_id, idempotency_key)
      end

      # --- Media ---

      # Download an inbound media file (e.g. from a message attachment's
      # `external_id`). Returns a RawResponse: `data` holds the raw bytes,
      # `content_type` the MIME type.
      def media(profile_id, phone_number_id, media_id, profile_group_id: nil)
        @client.request(:get, "/profiles/#{profile_id}/whatsapp/media",
          params: { phone_number_id: phone_number_id, media_id: media_id },
          profile_group_id: profile_group_id,
          raw: true
        )
      end

      private

      # Reads and deletes send their arguments as query params; everything
      # else as a JSON body. Nil values are dropped.
      def call(http_method, profile_id, action, data, profile_group_id, idempotency_key = nil)
        path = "/profiles/#{profile_id}/whatsapp/#{action}"
        compact = data.compact

        if %i[get delete].include?(http_method)
          @client.request(http_method, path,
            params: compact.empty? ? nil : compact,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key
          )
        else
          @client.request(http_method, path,
            json: compact,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key
          )
        end
      end

      def group_members(http_method, profile_id, action, phone_number_id, group_id, phone_numbers,
        profile_group_id, idempotency_key)
        call(http_method, profile_id, action,
          { phone_number_id: phone_number_id, group_id: group_id, phone_numbers: phone_numbers },
          profile_group_id, idempotency_key)
      end
    end
  end
end
