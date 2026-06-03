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
      attr_accessor :id, :name, :platform, :profile_group_id, :status, :uid, :username
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
                    :platform_data, :posted_at, :created_at
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
                    :author_avatar_url, :platform_data, :posted_at, :created_at
    end

    DATA_CLASSES = {
      "post.processed" => PostProcessedData,
      "post.imported" => PostImportedData,
      "platform_post.published" => PlatformPostData,
      "platform_post.failed" => PlatformPostData,
      "platform_post.failed_waiting_for_retry" => PlatformPostData,
      "platform_post.insights" => PlatformPostData,
      "profile.connected" => ProfileEventData,
      "profile.disconnected" => ProfileEventData,
      "profile.stats" => ProfileStatsData,
      "media.failed" => MediaFailedData,
      "comment.created" => CommentCreatedData,
      "profile_comment.created" => ProfileCommentCreatedData,
      "message.received" => MessageEventData,
      "message.sent" => MessageEventData,
      "message.delivered" => MessageEventData,
      "message.read" => MessageEventData,
      "message.edited" => MessageEventData,
      "message.deleted" => MessageEventData,
      "message.failed_waiting_for_retry" => MessageEventData,
      "message.failed" => MessageEventData,
      "reaction.received" => ReactionEventData
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
