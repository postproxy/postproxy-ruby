module PostProxy
  module Resources
    class Messages
      def initialize(client)
        @client = client
      end

      def list(chat_id, page: nil, per_page: nil, direction: nil, status: nil, profile_group_id: nil)
        params = {}
        params[:page] = page if page
        params[:per_page] = per_page if per_page
        params[:direction] = direction if direction
        params[:status] = status if status

        result = @client.request(:get, "/chats/#{chat_id}/messages", params: params, profile_group_id: profile_group_id)
        messages = (result[:data] || []).map { |m| Message.new(**m) }
        PaginatedResponse.new(
          data: messages,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      # quick_replies, buttons, and card are Facebook and Instagram only — they
      # return 422 on Telegram and Bluesky, where reply_markup is the
      # equivalent. They are sent on the JSON path only, so pass media as hosted
      # URLs rather than media_files when combining with an attachment.
      #
      # Each accepts model instances or plain hashes.
      #
      # `elements` sends a carousel of up to 10 cards (Facebook and Instagram);
      # it can't be combined with body, buttons or card.
      #
      # WhatsApp: send exactly one of body, media, `template`, `interactive`,
      # `location` or `contacts`. Outside the 24-hour window only a `template`
      # gets through. `category: "utility"` sends a text message under the
      # utility category; `link_preview` toggles URL previews, `voice_note`
      # delivers an audio attachment as a voice note, and `filename` names a
      # document attachment.
      def send_message(chat_id, body: nil, media: nil, media_files: nil, tag: nil,
                       reply_to_external_id: nil, reply_markup: nil,
                       quick_replies: nil, buttons: nil, card: nil, elements: nil,
                       template: nil, interactive: nil, location: nil, contacts: nil,
                       category: nil, link_preview: nil, voice_note: nil, filename: nil,
                       profile_group_id: nil, idempotency_key: nil)
        has_files = media_files && !media_files.empty?

        if has_files
          form_data = {}
          form_data["body"] = body if body
          form_data["tag"] = tag if tag
          form_data["reply_to_external_id"] = reply_to_external_id if reply_to_external_id
          form_data["voice_note"] = voice_note.to_s unless voice_note.nil?
          form_data["filename"] = filename if filename

          files = []
          media&.each do |m|
            files << ["media[]", nil, m, "text/plain"]
          end
          media_files.each do |path|
            path = path.to_s
            filename = File.basename(path)
            content_type = mime_type_for(filename)
            io = File.open(path, "rb")
            files << ["media[]", filename, io, content_type]
          end

          result = @client.request(:post, "/chats/#{chat_id}/messages",
            data: form_data,
            files: files,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key
          )
        else
          json_body = {}
          json_body[:body] = body if body
          json_body[:media] = media if media
          json_body[:tag] = tag if tag
          json_body[:reply_to_external_id] = reply_to_external_id if reply_to_external_id
          json_body[:reply_markup] = reply_markup if reply_markup
          json_body[:quick_replies] = quick_replies.map { |q| serialize_interactive(q) } if quick_replies
          json_body[:buttons] = buttons.map { |b| serialize_interactive(b) } if buttons
          json_body[:card] = serialize_interactive(card) if card
          json_body[:elements] = elements.map { |e| serialize_interactive(e) } if elements
          json_body[:template] = serialize_interactive(template) if template
          json_body[:interactive] = interactive if interactive
          json_body[:location] = serialize_interactive(location) if location
          json_body[:contacts] = contacts if contacts
          json_body[:category] = category if category
          json_body[:link_preview] = link_preview unless link_preview.nil?
          json_body[:voice_note] = voice_note unless voice_note.nil?
          json_body[:filename] = filename if filename

          result = @client.request(:post, "/chats/#{chat_id}/messages",
            json: json_body,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key
          )
        end

        Message.new(**result)
      end
      alias_method :send, :send_message

      def get(message_id, profile_group_id: nil)
        result = @client.request(:get, "/messages/#{message_id}", profile_group_id: profile_group_id)
        Message.new(**result)
      end

      def edit(message_id, body: nil, reply_markup: nil, profile_group_id: nil, idempotency_key: nil)
        json_body = {}
        json_body[:body] = body if body
        json_body[:reply_markup] = reply_markup if reply_markup

        result = @client.request(:patch, "/messages/#{message_id}",
          json: json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Message.new(**result)
      end

      def react(message_id, reaction: nil, emoji: nil, profile_group_id: nil, idempotency_key: nil)
        json_body = {}
        json_body[:reaction] = reaction if reaction
        json_body[:emoji] = emoji if emoji

        result = @client.request(:post, "/messages/#{message_id}/react",
          json: json_body.empty? ? nil : json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Message.new(**result)
      end

      def unreact(message_id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:delete, "/messages/#{message_id}/unreact",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Message.new(**result)
      end

      private

      # Interactive params accept model instances or plain hashes. Models expose
      # to_h with nils dropped, so an omitted content_type stays omitted rather
      # than being sent as null.
      def serialize_interactive(value)
        value.respond_to?(:to_h) && !value.is_a?(Hash) ? value.to_h : value
      end

      def mime_type_for(filename)
        case File.extname(filename).downcase
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".png" then "image/png"
        when ".gif" then "image/gif"
        when ".webp" then "image/webp"
        when ".mp4" then "video/mp4"
        when ".mov" then "video/quicktime"
        when ".avi" then "video/x-msvideo"
        when ".webm" then "video/webm"
        when ".mp3" then "audio/mpeg"
        when ".ogg" then "audio/ogg"
        when ".m4a" then "audio/mp4"
        when ".pdf" then "application/pdf"
        else "application/octet-stream"
        end
      end
    end
  end
end
