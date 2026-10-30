require "json"

module PostProxy
  class WebhookParseError < StandardError; end

  module WebhookEvents
    class Event < Model
      attr_accessor :id, :type, :created_at, :data
    end

    class PostProcessedPlatform < Model
      attr_accessor :id, :platform, :name
    end

    class PostProcessedData < Model
      attr_accessor :id, :body, :status, :scheduled_at, :created_at, :platforms

      def initialize(**attrs)
        @platforms = []
        super
        @platforms = (@platforms || []).map do |p|
          p.is_a?(PostProcessedPlatform) ? p : PostProcessedPlatform.new(**p.transform_keys(&:to_sym))
        end
      end
    end

    class ImportedProfile < Model
      attr_accessor :id, :name, :platform
    end

    class PostImportedData < Model
      attr_accessor :id, :body, :source, :posted_at, :created_at,
                    :platform, :profile, :platform_post_id, :public_id

      def initialize(**attrs)
        @profile = nil
        super
        @profile = ImportedProfile.new(**@profile.transform_keys(&:to_sym)) if @profile.is_a?(Hash)
      end
    end

    class PlatformPostData < Model
      attr_accessor :id, :post_id, :platform, :profile_id, :profile_name,
                    :status, :error, :error_details, :platform_id, :insights

      def initialize(**attrs)
        @error_details = nil
        @insights = nil
        super
        @error_details = ErrorDetails.new(**@error_details.transform_keys(&:to_sym)) if @error_details.is_a?(Hash)
      end
    end

    class ProfileEventData < Model
      # `origin` is set on `profile.disconnected`: "user" or "automated".
      # With "automated", `error` says why PostProxy deactivated it (e.g.
      # "Twitter access revoked") and `error_details` carries the raw platform
      # error, when available.
      attr_accessor :id, :name, :platform, :profile_group_id, :status, :uid,
                    :platform_id, :username, :origin, :error, :error_details

      def initialize(**attrs)
        @error = nil
        @error_details = nil
        super
        @error_details = ErrorDetails.new(**@error_details.transform_keys(&:to_sym)) if @error_details.is_a?(Hash)
      end
    end

    # `id` is the placement's id on the platform (page id, phone number id,
    # ...). `placement.name_status_updated` adds `decision`, `requested_name`
    # and `rejection_reason`; `placement.quality_updated` adds `event`,
    # `current_limit` and `old_limit`.
    class PlacementEventData < Model
      attr_accessor :id, :name, :platform, :profile_group_id, :profile_id,
                    :profile_name, :metadata, :decision, :requested_name,
                    :rejection_reason, :event, :current_limit, :old_limit
    end

    class PlacementsSyncedData < ProfileEventData
      attr_accessor :placements_sync_status, :placements

      def initialize(**attrs)
        @placements_sync_status = nil
        @placements = []
        super
        @placements = (@placements || []).map do |p|
          p.is_a?(PlacementEventData) ? p : PlacementEventData.new(**p.transform_keys(&:to_sym))
        end
      end
    end

    class ProfileStatsData < Model
      attr_accessor :profile_id, :platform, :placement_id, :stats, :recorded_at
    end

    class MediaFailedData < Model
      attr_accessor :id, :post_id, :content_type, :status, :error_message
    end

    class CommentCreatedData < Model
      attr_accessor :id, :post_id, :platform_post_id, :platform, :external_id,
                    :parent_external_id, :body, :status, :author_external_id,
                    :author_name, :author_username, :author_avatar_url,
                    :like_count, :reply_count, :is_hidden, :permalink,
                    :platform_data, :profile_id, :error, :error_details,
                    :external_edited_at, :posted_at, :created_at

      def initialize(**attrs)
        @error_details = nil
        super
        @error_details = ErrorDetails.new(**@error_details.transform_keys(&:to_sym)) if @error_details.is_a?(Hash)
      end
    end

    class MessageEventData < Model
      attr_accessor :message

      def initialize(**attrs)
        @message = nil
        super
        @message = Message.new(**@message.transform_keys(&:to_sym)) if @message.is_a?(Hash)
      end
    end

    class ReactionEventData < Model
      attr_accessor :message, :sender_external_id, :action, :reaction, :emoji, :occurred_at

      def initialize(**attrs)
        @message = nil
        @reaction = nil
        @emoji = nil
        @occurred_at = nil
        super
        @message = Message.new(**@message.transform_keys(&:to_sym)) if @message.is_a?(Hash)
      end
    end

    class ProfileCommentCreatedData < Model
      attr_accessor :id, :profile_id, :platform, :placement_id, :external_id,
                    :parent_external_id, :body, :status, :author_username,
                    :author_avatar_url, :platform_data, :error, :error_details,
                    :permalink, :posted_at, :created_at

      def initialize(**attrs)
        @error_details = nil
        super
        @error_details = ErrorDetails.new(**@error_details.transform_keys(&:to_sym)) if @error_details.is_a?(Hash)
      end
    end

    class WebhookChatData < Model
      attr_accessor :id, :profile_id, :platform, :external_placement_id, :group,
                    :participant_external_id, :participant_username,
                    :participant_name, :last_inbound_at, :last_outbound_at,
                    :last_message_at
    end

    # `ctwa_clid` is the click-to-WhatsApp ad click id.
    class ReferralEventData < Model
      attr_accessor :chat, :ref, :source, :type, :ctwa_clid, :occurred_at

      def initialize(**attrs)
        @chat = nil
        super
        @chat = WebhookChatData.new(**@chat.transform_keys(&:to_sym)) if @chat.is_a?(Hash)
      end
    end

    # Another Meta app passed or took a Facebook / Instagram conversation.
    # `previous_owner_app_id` is nil when the conversation was idle.
    class ThreadControlChangedEventData < Model
      attr_accessor :chat, :previous_owner_app_id, :new_owner_app_id, :metadata, :occurred_at

      def initialize(**attrs)
        @chat = nil
        @previous_owner_app_id = nil
        @new_owner_app_id = nil
        @metadata = nil
        @occurred_at = nil
        super
        @chat = WebhookChatData.new(**@chat.transform_keys(&:to_sym)) if @chat.is_a?(Hash)
      end
    end

    # Another Meta app asked PostProxy to pass a conversation.
    class ThreadControlRequestedEventData < Model
      attr_accessor :chat, :requested_owner_app_id, :metadata, :occurred_at

      def initialize(**attrs)
        @chat = nil
        @requested_owner_app_id = nil
        @metadata = nil
        @occurred_at = nil
        super
        @chat = WebhookChatData.new(**@chat.transform_keys(&:to_sym)) if @chat.is_a?(Hash)
      end
    end

    class MessageTemplateEventData < Model
      attr_accessor :id, :external_id, :profile_id, :platform, :name, :language,
                    :category, :status, :rejected_reason, :quality_score
    end

    class WhatsAppAutomaticEventData < Model
      attr_accessor :profile_id, :chat_id, :participant_external_id,
                    :external_message_id, :event_name, :ctwa_clid, :custom_data
    end

    DATA_CLASSES = {
      "post.processed" => PostProcessedData,
      "post.imported" => PostImportedData,
      "platform_post.published" => PlatformPostData,
      "platform_post.failed" => PlatformPostData,
      "platform_post.failed_waiting_for_retry" => PlatformPostData,
      "platform_post.edited" => PlatformPostData,
      "platform_post.edit_failed" => PlatformPostData,
      "platform_post.insights" => PlatformPostData,
      "profile.connected" => ProfileEventData,
      "profile.disconnected" => ProfileEventData,
      "profile.stats" => ProfileStatsData,
      "profile.placements_synced" => PlacementsSyncedData,
      "placement.orphaned" => PlacementEventData,
      "placement.restored" => PlacementEventData,
      "media.failed" => MediaFailedData,
      "comment.created" => CommentCreatedData,
      "comment.failed" => CommentCreatedData,
      "comment.failed_waiting_for_retry" => CommentCreatedData,
      "comment.delivery_unconfirmed" => CommentCreatedData,
      "comment.edited" => CommentCreatedData,
      "comment.edit_failed" => CommentCreatedData,
      "profile_comment.created" => ProfileCommentCreatedData,
      "profile_comment.failed" => ProfileCommentCreatedData,
      "profile_comment.failed_waiting_for_retry" => ProfileCommentCreatedData,
      "profile_comment.edited" => ProfileCommentCreatedData,
      "profile_comment.deleted" => ProfileCommentCreatedData,
      "message.received" => MessageEventData,
      "message.sent" => MessageEventData,
      "message.delivered" => MessageEventData,
      "message.read" => MessageEventData,
      "message.edited" => MessageEventData,
      "message.deleted" => MessageEventData,
      "message.failed_waiting_for_retry" => MessageEventData,
      "message.failed" => MessageEventData,
      "reaction.received" => ReactionEventData,
      "referral.received" => ReferralEventData,
      "chat.thread_control_changed" => ThreadControlChangedEventData,
      "chat.thread_control_requested" => ThreadControlRequestedEventData,
      "message_template.status_updated" => MessageTemplateEventData,
      "message_template.category_updated" => MessageTemplateEventData,
      "placement.name_status_updated" => PlacementEventData,
      "placement.quality_updated" => PlacementEventData,
      "whatsapp.automatic_event" => WhatsAppAutomaticEventData
    }.freeze

    # Parse a webhook body and return a typed Event. `data` is parsed into the
    # appropriate model based on `type`. Raises WebhookParseError on bad input.
    def self.parse(body)
      parsed =
        case body
        when String then JSON.parse(body, symbolize_names: true)
        when Hash then body.transform_keys(&:to_sym)
        else raise WebhookParseError, "Webhook body must be a String or Hash"
        end
    rescue JSON::ParserError => e
      raise WebhookParseError, "Invalid JSON: #{e.message}"
    else
      type = parsed[:type].to_s
      raise WebhookParseError, "Unknown webhook event type: #{type.inspect}" unless DATA_CLASSES.key?(type)

      data_class = DATA_CLASSES[type]
      data_hash = (parsed[:data] || {}).transform_keys(&:to_sym)
      Event.new(
        id: parsed[:id],
        type: type,
        created_at: parsed[:created_at],
        data: data_class.new(**data_hash)
      )
    end
  end
end
