require "time"

module PostProxy
  class Model
    def initialize(**attrs)
      attrs.each do |key, value|
        if respond_to?(:"#{key}=")
          send(:"#{key}=", value)
        end
      end
    end

    def to_h
      instance_variables.each_with_object({}) do |var, hash|
        key = var.to_s.delete_prefix("@")
        hash[key.to_sym] = instance_variable_get(var)
      end
    end
  end

  class Profile < Model
    # `inactive_reason` says why an "inactive" profile was deactivated —
    # "network_taken" means the same account was connected elsewhere.
    # `platform_id` is the account's id on the platform.
    attr_accessor :id, :name, :username, :status, :inactive_reason, :platform,
                  :platform_id, :profile_group_id, :expires_at, :post_count,
                  :avatar_url, :platform_url, :placements_sync_status

    def initialize(**attrs)
      @username = nil
      @inactive_reason = nil
      @platform_id = nil
      @expires_at = nil
      @post_count = 0
      @avatar_url = nil
      @platform_url = nil
      @placements_sync_status = nil
      super
      @expires_at = parse_time(@expires_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class ProfileGroup < Model
    attr_accessor :id, :name, :profiles_count

    def initialize(**attrs)
      @profiles_count = 0
      super
    end
  end

  class Insights < Model
    attr_accessor :impressions, :on

    def initialize(**attrs)
      @impressions = nil
      @on = nil
      super
      @on = parse_time(@on)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class ErrorDetails < Model
    attr_accessor :platform_error_code, :platform_error_subcode, :platform_error_message, :postproxy_note

    def initialize(**attrs)
      @platform_error_code = nil
      @platform_error_subcode = nil
      @platform_error_message = nil
      @postproxy_note = nil
      super
    end
  end

  # A file PostProxy generated for one platform, e.g. a TikTok cover.
  class PlatformAttachment < Model
    attr_accessor :id, :type, :status, :content_type, :url

    def initialize(**attrs)
      @content_type = nil
      @url = nil
      super
    end
  end

  class PlatformResult < Model
    attr_accessor :platform, :profile_id, :profile_name, :status, :permalink,
                  :params, :error, :error_details, :attempted_at, :insights,
                  :attachments

    def initialize(**attrs)
      @profile_id = nil
      @profile_name = nil
      @permalink = nil
      @params = nil
      @error = nil
      @error_details = nil
      @attempted_at = nil
      @insights = nil
      @attachments = nil
      super
      @attempted_at = parse_time(@attempted_at)
      @insights = Insights.new(**@insights) if @insights.is_a?(Hash)
      @error_details = ErrorDetails.new(**@error_details.transform_keys(&:to_sym)) if @error_details.is_a?(Hash)
      @attachments = @attachments&.map do |a|
        a.is_a?(PlatformAttachment) ? a : PlatformAttachment.new(**a.transform_keys(&:to_sym))
      end
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class MediaPlatformError < Model
    attr_accessor :platform, :status, :error, :error_details

    def initialize(**attrs)
      @error = nil
      @error_details = nil
      super
      @error_details = ErrorDetails.new(**@error_details.transform_keys(&:to_sym)) if @error_details.is_a?(Hash)
    end
  end

  class Media < Model
    attr_accessor :id, :status, :error_message, :content_type, :source_url, :url, :platforms

    def initialize(**attrs)
      @error_message = nil
      @source_url = nil
      @url = nil
      @platforms = nil
      super
      if @platforms.is_a?(Array)
        @platforms = @platforms.map do |p|
          p.is_a?(MediaPlatformError) ? p : MediaPlatformError.new(**p.transform_keys(&:to_sym))
        end
      end
    end
  end

  class ThreadChild < Model
    # Each thread item is delivered separately; `platforms` shows whether it
    # went out.
    attr_accessor :id, :body, :media, :platforms

    def initialize(**attrs)
      @media = []
      @platforms = []
      super
      @media = (@media || []).map do |m|
        m.is_a?(Media) ? m : Media.new(**m.transform_keys(&:to_sym))
      end
      @platforms = (@platforms || []).map do |p|
        p.is_a?(PlatformResult) ? p : PlatformResult.new(**p.transform_keys(&:to_sym))
      end
    end
  end

  class Timeslot < Model
    attr_accessor :id, :day, :time
  end

  class Queue < Model
    attr_accessor :id, :name, :description, :timezone, :enabled, :jitter,
                  :profile_group_id, :timeslots, :posts_count

    def initialize(**attrs)
      @description = nil
      @timeslots = []
      @posts_count = 0
      super
      @timeslots = (@timeslots || []).map do |t|
        t.is_a?(Timeslot) ? t : Timeslot.new(**t.transform_keys(&:to_sym))
      end
    end
  end

  class NextSlotResponse < Model
    attr_accessor :next_slot
  end

  class Post < Model
    # `source` is "postproxy" or "imported".
    attr_accessor :id, :body, :status, :scheduled_at, :created_at, :media, :platforms, :thread,
                  :queue_id, :queue_priority, :draft, :source

    def initialize(**attrs)
      @draft = nil
      @source = nil
      @scheduled_at = nil
      @media = []
      @platforms = []
      @thread = []
      @queue_id = nil
      @queue_priority = nil
      super
      @scheduled_at = parse_time(@scheduled_at)
      @created_at = parse_time(@created_at)
      @media = (@media || []).map do |m|
        m.is_a?(Media) ? m : Media.new(**m.transform_keys(&:to_sym))
      end
      @platforms = (@platforms || []).map do |p|
        p.is_a?(PlatformResult) ? p : PlatformResult.new(**p.transform_keys(&:to_sym))
      end
      @thread = (@thread || []).map do |t|
        t.is_a?(ThreadChild) ? t : ThreadChild.new(**t.transform_keys(&:to_sym))
      end
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class Webhook < Model
    attr_accessor :id, :url, :events, :enabled, :description, :secret,
                  :created_at, :updated_at

    def initialize(**attrs)
      @events = []
      @description = nil
      @secret = nil
      super
      @created_at = parse_time(@created_at)
      @updated_at = parse_time(@updated_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class WebhookDelivery < Model
    attr_accessor :id, :event_id, :event_type, :response_status,
                  :attempt_number, :success, :attempted_at, :created_at

    def initialize(**attrs)
      @response_status = nil
      super
      @attempted_at = parse_time(@attempted_at)
      @created_at = parse_time(@created_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class Placement < Model
    # `metadata` and `profile_group_id` are present in placements and
    # assign_placement_to_group responses.
    attr_accessor :id, :name, :avatar_url, :metadata, :profile_group_id
  end

  class AccountPlacementProfile < Model
    attr_accessor :id, :name, :connected
  end

  # Account-level placement, returned by Placements#list. A placement (a
  # Facebook Page, LinkedIn organization, WhatsApp number, ...) can be
  # reachable through several connected profiles; one of them is active.
  class AccountPlacement < Model
    attr_accessor :id, :platform, :external_id, :name, :avatar_url, :status,
                  :active_profile, :linked_profiles

    def initialize(**attrs)
      @avatar_url = nil
      @active_profile = nil
      @linked_profiles = []
      super
      if @active_profile.is_a?(Hash)
        @active_profile = AccountPlacementProfile.new(**@active_profile.transform_keys(&:to_sym))
      end
      @linked_profiles = (@linked_profiles || []).map do |p|
        p.is_a?(AccountPlacementProfile) ? p : AccountPlacementProfile.new(**p.transform_keys(&:to_sym))
      end
    end
  end

  class ApiKey < Model
    # `token` is only returned by ApiKeys#create — store it, it can't be read
    # again.
    attr_accessor :id, :name, :profile_group_id, :sandbox, :token, :created_at

    def initialize(**attrs)
      @profile_group_id = nil
      @sandbox = false
      @token = nil
      super
      @created_at = parse_time(@created_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  # Instagram DM ice breaker (FAQ prompt). May carry extra platform fields.
  class IceBreaker < Model
    attr_accessor :question, :payload

    def to_h
      { question: question, payload: payload }
    end
  end

  class IceBreakersResponse < Model
    attr_accessor :ice_breakers

    def initialize(**attrs)
      @ice_breakers = (attrs.delete(:ice_breakers) || []).map do |ib|
        ib.is_a?(IceBreaker) ? ib : IceBreaker.new(**ib)
      end
      super
    end
  end

  class StatsRecord < Model
    # `raw_stats` carries every metric under its original platform name, e.g.
    # `views` for Instagram or `impression_count` for Twitter/X.
    attr_accessor :stats, :raw_stats, :recorded_at

    def initialize(**attrs)
      @stats = {}
      @raw_stats = {}
      @recorded_at = nil
      super
      @recorded_at = parse_time(@recorded_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class PlatformStats < Model
    attr_accessor :profile_id, :platform, :records

    def initialize(**attrs)
      @records = []
      super
      @records = (@records || []).map do |r|
        r.is_a?(StatsRecord) ? r : StatsRecord.new(**r.transform_keys(&:to_sym))
      end
    end
  end

  class PostStats < Model
    attr_accessor :platforms

    def initialize(**attrs)
      @platforms = []
      super
      @platforms = (@platforms || []).map do |p|
        p.is_a?(PlatformStats) ? p : PlatformStats.new(**p.transform_keys(&:to_sym))
      end
    end
  end

  class StatsResponse
    attr_reader :data

    def initialize(data:)
      @data = data
    end
  end

  class ListResponse
    attr_reader :data

    def initialize(data:)
      @data = data
    end
  end

  class PaginatedResponse < ListResponse
    attr_reader :total, :page, :per_page

    def initialize(data:, total:, page:, per_page:)
      super(data: data)
      @total = total
      @page = page
      @per_page = per_page
    end
  end

  class Attachment < Model
    attr_accessor :id, :type, :url, :status, :external_id

    def initialize(**attrs)
      @url = nil
      @external_id = nil
      super
    end
  end

  class Reaction < Model
    attr_accessor :sender_external_id, :emoji, :reaction, :at

    def initialize(**attrs)
      @emoji = nil
      @reaction = nil
      @at = nil
      super
      @at = parse_time(@at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class Comment < Model
    attr_accessor :id, :external_id, :body, :status, :author_username,
                  :author_avatar_url, :author_external_id, :metadata,
                  :parent_external_id, :like_count, :is_hidden, :permalink,
                  :platform_data, :attachments, :external_edited_at, :posted_at,
                  :created_at, :replies

    def initialize(**attrs)
      @external_id = nil
      @author_avatar_url = nil
      @author_external_id = nil
      @metadata = nil
      @parent_external_id = nil
      @like_count = 0
      @is_hidden = false
      @permalink = nil
      @platform_data = nil
      @attachments = []
      @external_edited_at = nil
      @replies = []
      super
      @external_edited_at = parse_time(@external_edited_at)
      @posted_at = parse_time(@posted_at)
      @created_at = parse_time(@created_at)
      @attachments = (@attachments || []).map do |a|
        a.is_a?(Attachment) ? a : Attachment.new(**a.transform_keys(&:to_sym))
      end
      @replies = (@replies || []).map do |r|
        r.is_a?(Comment) ? r : Comment.new(**r.transform_keys(&:to_sym))
      end
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class Chat < Model
    # `external_placement_id` is the page / phone number the chat runs through;
    # `group` marks a WhatsApp group chat. `within_messaging_window` is
    # WhatsApp-only: whether the 24-hour customer service window is open —
    # when it's closed only a template can be sent. Facebook and Instagram
    # chats carry `thread_control` in `metadata` once known (`owner_app_id`,
    # `expires_at`, `updated_at`).
    attr_accessor :id, :profile_id, :platform, :external_placement_id, :group,
                  :participant_external_id, :participant_username,
                  :participant_name, :participant_avatar_url,
                  :external_conversation_id, :last_inbound_at, :last_outbound_at,
                  :last_message_at, :metadata, :archived,
                  :within_messaging_window, :created_at

    def initialize(**attrs)
      @external_placement_id = nil
      @group = false
      @within_messaging_window = nil
      @participant_username = nil
      @participant_name = nil
      @participant_avatar_url = nil
      @external_conversation_id = nil
      @last_inbound_at = nil
      @last_outbound_at = nil
      @last_message_at = nil
      @metadata = nil
      @archived = nil
      super
      @last_inbound_at = parse_time(@last_inbound_at)
      @last_outbound_at = parse_time(@last_outbound_at)
      @last_message_at = parse_time(@last_message_at)
      @created_at = parse_time(@created_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  # A tappable chip above the participant's composer, gone once tapped.
  # Facebook and Instagram only; up to 13 per send. +content_type+ is optional
  # on send (only "text" is accepted) and always present on responses.
  class QuickReply < Model
    attr_accessor :content_type, :title, :payload

    def initialize(**attrs)
      @content_type = nil
      super
    end

    def to_h
      { content_type: @content_type, title: @title, payload: @payload }.compact
    end
  end

  # A button attached to the message, delivered as a Meta generic template.
  # Facebook and Instagram only; up to 3 per send. +url+ is required and must be
  # https when +type+ is "web_url"; +payload+ is required when +type+ is
  # "postback". +type+ is a plain string rather than an enum so a new Meta
  # button type needs no SDK release.
  class MessageButton < Model
    attr_accessor :type, :title, :url, :payload

    def initialize(**attrs)
      @url = nil
      @payload = nil
      super
    end

    def to_h
      { type: @type, title: @title, url: @url, payload: @payload }.compact
    end
  end

  class CardDefaultAction < Model
    attr_accessor :type, :url

    def to_h
      { type: @type, url: @url }.compact
    end
  end

  # Extra fields for the generic-template element that carries +buttons+.
  # Requires +buttons+. +subtitle+ is capped at 80 characters, and both URLs
  # must be https.
  class MessageCard < Model
    attr_accessor :subtitle, :image_url, :default_action

    def initialize(**attrs)
      @subtitle = nil
      @image_url = nil
      @default_action = nil
      super
      if @default_action && !@default_action.is_a?(CardDefaultAction)
        @default_action = CardDefaultAction.new(**@default_action.transform_keys(&:to_sym))
      end
    end

    def to_h
      {
        subtitle: @subtitle,
        image_url: @image_url,
        default_action: @default_action&.to_h
      }.compact
    end
  end

  # One card of a horizontally scrolling carousel. Facebook and Instagram only;
  # up to 10 per send. +title+ (80 characters or fewer) plus at least one
  # other field is required; +buttons+ takes up to 3.
  class MessageElement < Model
    attr_accessor :title, :subtitle, :image_url, :default_action, :buttons

    def initialize(**attrs)
      @subtitle = nil
      @image_url = nil
      @default_action = nil
      @buttons = nil
      super
      if @default_action && !@default_action.is_a?(CardDefaultAction)
        @default_action = CardDefaultAction.new(**@default_action.transform_keys(&:to_sym))
      end
      @buttons = @buttons&.map do |b|
        b.is_a?(MessageButton) ? b : MessageButton.new(**b.transform_keys(&:to_sym))
      end
    end

    def to_h
      {
        title: @title,
        subtitle: @subtitle,
        image_url: @image_url,
        default_action: @default_action&.to_h,
        buttons: @buttons&.map(&:to_h)
      }.compact
    end
  end

  class MessageLocation < Model
    attr_accessor :latitude, :longitude, :name, :address

    def initialize(**attrs)
      @name = nil
      @address = nil
      super
    end

    def to_h
      { latitude: @latitude, longitude: @longitude, name: @name, address: @address }.compact
    end
  end

  # WhatsApp template send. Address the template by +id+ (PostProxy or Meta
  # id) or by +name+ (+ +language+ when it exists in several). +variables+ are
  # positional: header, then body, then dynamic URL buttons. +button_params+
  # are hashes with +index+ and +sub_type+ ("url", "copy_code", "flow",
  # "quick_reply", "voice_call"); +header_media+ is { link: } or { id: } for
  # an image / video / document header.
  class MessageTemplateInput < Model
    attr_accessor :id, :name, :language, :variables, :button_params,
                  :header_media, :header_location

    def to_h
      {
        id: @id,
        name: @name,
        language: @language,
        variables: @variables,
        button_params: @button_params,
        header_media: @header_media,
        header_location: @header_location.is_a?(MessageLocation) ? @header_location.to_h : @header_location
      }.compact
    end
  end

  # The template an outbound WhatsApp message was sent with.
  class MessageTemplateRef < Model
    attr_accessor :id, :external_id, :name, :language, :variables

    def initialize(**attrs)
      @external_id = nil
      @variables = nil
      super
    end
  end

  # Set on inbound messages created by a tap on an element you sent. Derived
  # from platform_data rather than stored, so it also resolves for taps ingested
  # before PostProxy exposed this field. +kind+ is one of "quick_reply",
  # "postback", or "callback_query" — the last is Telegram, so this is not
  # Meta-only even though the send params are.
  class TappedAction < Model
    attr_accessor :kind, :payload, :title

    def initialize(**attrs)
      @title = nil
      super
    end
  end

  class Message < Model
    attr_accessor :id, :chat_id, :external_id, :direction, :body, :status,
                  :tag, :external_comment_id, :error_message, :error_details,
                  :platform_data, :external_posted_at, :external_delivered_at,
                  :external_read_at, :external_edited_at, :reply_to_external_id,
                  :reply_markup, :quick_replies, :buttons, :card, :elements,
                  :tapped_action, :story_reply, :interactive, :location,
                  :contacts, :template, :external_deleted_at, :reactions,
                  :attachments, :is_unsupported, :created_at

    def initialize(**attrs)
      @external_id = nil
      @body = nil
      @tag = nil
      @external_comment_id = nil
      @error_message = nil
      @platform_data = nil
      @external_posted_at = nil
      @external_delivered_at = nil
      @external_read_at = nil
      @external_edited_at = nil
      @reply_to_external_id = nil
      @reply_markup = nil
      @quick_replies = nil
      @buttons = nil
      @card = nil
      @elements = nil
      @tapped_action = nil
      @error_details = nil
      @story_reply = nil
      # WhatsApp-only payloads.
      @interactive = nil
      @location = nil
      @contacts = nil
      @template = nil
      @external_deleted_at = nil
      @reactions = []
      @attachments = []
      @is_unsupported = false
      super
      @external_posted_at = parse_time(@external_posted_at)
      @external_delivered_at = parse_time(@external_delivered_at)
      @external_read_at = parse_time(@external_read_at)
      @external_edited_at = parse_time(@external_edited_at)
      @external_deleted_at = parse_time(@external_deleted_at)
      @created_at = parse_time(@created_at)
      @reactions = (@reactions || []).map do |r|
        r.is_a?(Reaction) ? r : Reaction.new(**r.transform_keys(&:to_sym))
      end
      @attachments = (@attachments || []).map do |a|
        a.is_a?(Attachment) ? a : Attachment.new(**a.transform_keys(&:to_sym))
      end
      # Left nil rather than [] when absent — the API omits these on non-Meta
      # networks, and an empty array would read as "sent with none".
      @quick_replies = @quick_replies&.map do |q|
        q.is_a?(QuickReply) ? q : QuickReply.new(**q.transform_keys(&:to_sym))
      end
      @buttons = @buttons&.map do |b|
        b.is_a?(MessageButton) ? b : MessageButton.new(**b.transform_keys(&:to_sym))
      end
      if @card && !@card.is_a?(MessageCard)
        @card = MessageCard.new(**@card.transform_keys(&:to_sym))
      end
      if @tapped_action && !@tapped_action.is_a?(TappedAction)
        @tapped_action = TappedAction.new(**@tapped_action.transform_keys(&:to_sym))
      end
      @elements = @elements&.map do |e|
        e.is_a?(MessageElement) ? e : MessageElement.new(**e.transform_keys(&:to_sym))
      end
      if @location.is_a?(Hash)
        @location = MessageLocation.new(**@location.transform_keys(&:to_sym))
      end
      if @template.is_a?(Hash)
        @template = MessageTemplateRef.new(**@template.transform_keys(&:to_sym))
      end
      @error_details = ErrorDetails.new(**@error_details.transform_keys(&:to_sym)) if @error_details.is_a?(Hash)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class ProfileComment < Model
    attr_accessor :id, :external_id, :parent_external_id, :placement_id,
                  :body, :status, :author_username, :author_avatar_url,
                  :platform_data, :posted_at, :created_at, :replies

    def initialize(**attrs)
      @parent_external_id = nil
      @author_username = nil
      @author_avatar_url = nil
      @platform_data = nil
      @replies = []
      super
      @posted_at = parse_time(@posted_at)
      @created_at = parse_time(@created_at)
      @replies = (@replies || []).map do |r|
        r.is_a?(ProfileComment) ? r : ProfileComment.new(**r.transform_keys(&:to_sym))
      end
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class AcceptedResponse < Model
    attr_accessor :accepted
  end

  # A comment from Comments#list_all. Flat: replies are their own entries
  # linked to their parent by `parent_external_id` rather than nested under
  # `replies`.
  class BulkComment < Model
    attr_accessor :post_id, :profile_id, :platform, :id, :external_id, :body,
                  :status, :author_username, :author_avatar_url,
                  :author_external_id, :metadata, :parent_external_id,
                  :like_count, :is_hidden, :permalink, :platform_data,
                  :attachments, :external_edited_at, :posted_at, :created_at

    def initialize(**attrs)
      @external_id = nil
      @author_username = nil
      @author_avatar_url = nil
      @author_external_id = nil
      @metadata = nil
      @parent_external_id = nil
      @like_count = 0
      @is_hidden = false
      @permalink = nil
      @platform_data = nil
      @attachments = []
      @external_edited_at = nil
      @posted_at = nil
      super
      @external_edited_at = parse_time(@external_edited_at)
      @posted_at = parse_time(@posted_at)
      @created_at = parse_time(@created_at)
      @attachments = (@attachments || []).map do |a|
        a.is_a?(Attachment) ? a : Attachment.new(**a.transform_keys(&:to_sym))
      end
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  # A record of one post pull for a profile — the sync fired when the profile
  # connects, the recurring poll, or a backfill.
  class PostSync < Model
    attr_accessor :id, :profile_id, :placement_id, :kind, :trigger, :status,
                  :started_at, :completed_at, :posts_seen, :posts_imported,
                  :backfill_from, :oldest_posted_at, :error, :created_at

    def initialize(**attrs)
      @placement_id = nil
      @started_at = nil
      @completed_at = nil
      @posts_seen = 0
      # Posts that were new and got created — lower than `posts_seen` whenever
      # the run re-read posts you already have.
      @posts_imported = 0
      @backfill_from = nil
      # Publish date of the oldest post the run reached.
      @oldest_posted_at = nil
      @error = nil
      super
      @started_at = parse_time(@started_at)
      @completed_at = parse_time(@completed_at)
      @backfill_from = parse_time(@backfill_from)
      @oldest_posted_at = parse_time(@oldest_posted_at)
      @created_at = parse_time(@created_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  # A chat (DM) sync run, started by Profiles#backfill_chats or on connect.
  class ChatSync < Model
    attr_accessor :id, :profile_id, :placement_id, :kind, :trigger, :status,
                  :started_at, :completed_at, :chats_seen, :messages_imported,
                  :backfill_from, :oldest_updated_at, :error, :created_at

    def initialize(**attrs)
      @placement_id = nil
      @started_at = nil
      @completed_at = nil
      @chats_seen = 0
      @messages_imported = 0
      @backfill_from = nil
      @oldest_updated_at = nil
      @error = nil
      super
      @started_at = parse_time(@started_at)
      @completed_at = parse_time(@completed_at)
      @backfill_from = parse_time(@backfill_from)
      @oldest_updated_at = parse_time(@oldest_updated_at)
      @created_at = parse_time(@created_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class DeleteResponse < Model
    attr_accessor :deleted
  end

  # Body bytes and content type of a binary download (WhatsApp#media).
  class RawResponse < Model
    attr_accessor :data, :content_type
  end

  class DeletingPlatform < Model
    attr_accessor :post_profile_id, :platform
  end

  class DeleteOnPlatformResponse < Model
    attr_accessor :success, :deleting

    def initialize(**attrs)
      @deleting = []
      super
      @deleting = (@deleting || []).map do |entry|
        entry.is_a?(DeletingPlatform) ? entry : DeletingPlatform.new(**entry)
      end
    end
  end

  class SuccessResponse < Model
    attr_accessor :success
  end

  # OAuth-style connection response (facebook, instagram, twitter, etc.).
  class ConnectionResponse < Model
    attr_accessor :url, :success
  end

  # Alias for clarity at call sites; same shape as ConnectionResponse.
  OAuthConnectionResponse = ConnectionResponse

  class SyncProfile < Model
    attr_accessor :id, :network, :name, :external_username
  end

  class BlueskyConnectionResponse < Model
    attr_accessor :success, :profile

    def initialize(**attrs)
      @profile = nil
      super
      @profile = SyncProfile.new(**@profile.transform_keys(&:to_sym)) if @profile.is_a?(Hash)
    end
  end

  class TelegramConnectionResponse < Model
    attr_accessor :success, :profile, :next_step

    def initialize(**attrs)
      @profile = nil
      @next_step = nil
      super
      @profile = SyncProfile.new(**@profile.transform_keys(&:to_sym)) if @profile.is_a?(Hash)
    end
  end

  class ProfileStats < Model
    attr_accessor :profile_id, :platform, :placement_id, :records

    def initialize(**attrs)
      @placement_id = nil
      @records = []
      super
      @records = (@records || []).map do |r|
        r.is_a?(StatsRecord) ? r : StatsRecord.new(**r.transform_keys(&:to_sym))
      end
    end
  end

  class ProfileStatsResponse
    attr_reader :data

    def initialize(data:)
      @data = data.is_a?(ProfileStats) ? data : ProfileStats.new(**data.transform_keys(&:to_sym))
    end
  end

  # One day of a DailyStats series. Normalized metrics (e.g. `impressions`,
  # `viewers`) vary by platform, so they live in `values` and are also
  # readable as `record[:impressions]`.
  class DailyStatsRecord
    attr_reader :date, :platform_stats, :values

    def initialize(**attrs)
      attrs = attrs.transform_keys(&:to_sym)
      @date = attrs.delete(:date)
      @platform_stats = attrs.delete(:platform_stats)
      @values = attrs
    end

    def [](key)
      @values[key.to_sym]
    end

    def to_h
      { date: @date, platform_stats: @platform_stats }.merge(@values)
    end
  end

  class DailyStats < Model
    # `metrics` describes each metric in `records`.
    attr_accessor :profile_id, :platform, :placement_id, :attribution, :from,
                  :to, :data_timezone, :records, :metrics

    def initialize(**attrs)
      @placement_id = nil
      @data_timezone = nil
      @records = []
      @metrics = {}
      super
      @records = (@records || []).map do |r|
        r.is_a?(DailyStatsRecord) ? r : DailyStatsRecord.new(**r)
      end
    end
  end

  class DailyStatsResponse
    attr_reader :data

    def initialize(data:)
      @data = data.is_a?(DailyStats) ? data : DailyStats.new(**data.transform_keys(&:to_sym))
    end
  end

  class FollowerHistoryRecord < Model
    attr_accessor :date, :followers_gained, :followers_lost, :followers_change, :followers_total
  end

  class FollowerHistory < Model
    attr_accessor :profile_id, :platform, :placement_id, :from, :to, :records

    def initialize(**attrs)
      @placement_id = nil
      @records = []
      super
      @records = (@records || []).map do |r|
        r.is_a?(FollowerHistoryRecord) ? r : FollowerHistoryRecord.new(**r.transform_keys(&:to_sym))
      end
    end
  end

  class FollowerHistoryResponse
    attr_reader :data

    def initialize(data:)
      @data = data.is_a?(FollowerHistory) ? data : FollowerHistory.new(**data.transform_keys(&:to_sym))
    end
  end

  # Instagram only. Cached for a short while server-side.
  class ParticipantStatus < Model
    attr_accessor :is_verified_user, :is_user_follow_business,
                  :is_business_follow_user, :fetched_at
  end

  # LinkedIn only: a company page URL (or vanity name) resolved to the URN you
  # @-mention it with in a post body.
  class ResolvedMention < Model
    attr_accessor :urn, :type, :name, :vanity_name
  end

  # --- Instagram collaboration invites ---

  # `media_url` is left out by Instagram for videos with copyrighted or
  # licensed audio.
  class InstagramCollaborationInvite < Model
    attr_accessor :media_id, :media_owner_username, :caption, :media_url

    def initialize(**attrs)
      @media_owner_username = nil
      @caption = nil
      @media_url = nil
      super
    end
  end

  # `next_cursor` is nil on the last page.
  class InstagramCollaborationInvitesResponse < Model
    attr_accessor :collaboration_invites, :next_cursor

    def initialize(**attrs)
      @collaboration_invites = []
      @next_cursor = nil
      super
      @collaboration_invites = (@collaboration_invites || []).map do |i|
        i.is_a?(InstagramCollaborationInvite) ? i : InstagramCollaborationInvite.new(**i.transform_keys(&:to_sym))
      end
    end
  end

  # `accepted` is set by accept, `declined` by decline.
  class InstagramCollaborationInviteResult < Model
    attr_accessor :media_id, :accepted, :declined
  end

  # --- Pinterest ---

  class PinterestBoardDeleted < Model
    attr_accessor :deleted, :board_id
  end

  # --- YouTube ---

  class YouTubePlaylist < Model
    attr_accessor :id, :title, :description, :privacy_status, :item_count,
                  :thumbnail_url, :published_at

    def initialize(**attrs)
      @thumbnail_url = nil
      @item_count = 0
      super
      @published_at = parse_time(@published_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  # `next_page_token` is nil on the last page.
  class YouTubePlaylistsResponse < Model
    attr_accessor :data, :next_page_token

    def initialize(**attrs)
      @data = []
      @next_page_token = nil
      super
      @data = (@data || []).map do |p|
        p.is_a?(YouTubePlaylist) ? p : YouTubePlaylist.new(**p.transform_keys(&:to_sym))
      end
    end
  end

  class YouTubePlaylistDeleted < Model
    attr_accessor :deleted, :playlist_id
  end

  # --- Chat thread control ---

  # Who controls a Facebook / Instagram conversation. Both nil when idle.
  class ThreadOwner < Model
    attr_accessor :app_id, :expires_at

    def initialize(**attrs)
      @app_id = nil
      @expires_at = nil
      super
      @expires_at = parse_time(@expires_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  # --- Google Business search keywords ---

  # `impressions` is nil for low-volume keywords; `impressions_threshold`
  # is then the upper bound Google reports instead.
  class SearchKeyword < Model
    attr_accessor :keyword, :impressions, :impressions_threshold

    def initialize(**attrs)
      @impressions = nil
      @impressions_threshold = nil
      super
    end
  end

  # `month` is "YYYY-MM".
  class SearchKeywordsMonth < Model
    attr_accessor :month, :keywords

    def initialize(**attrs)
      @keywords = []
      super
      @keywords = (@keywords || []).map do |k|
        k.is_a?(SearchKeyword) ? k : SearchKeyword.new(**k.transform_keys(&:to_sym))
      end
    end
  end

  class SearchKeywordsResponse < Model
    attr_accessor :months

    def initialize(**attrs)
      @months = []
      super
      @months = (@months || []).map do |m|
        m.is_a?(SearchKeywordsMonth) ? m : SearchKeywordsMonth.new(**m.transform_keys(&:to_sym))
      end
    end
  end

  # Platform-specific parameter structs

  # `alt_text` on every params class that has it takes a single string or an
  # array, one per media item in order.
  #
  # `link` makes a text-only link post (Facebook renders the preview card).
  # `made_with_ai` applies to photo posts only. `countries` are ISO 3166-1
  # alpha-2 codes; viewers elsewhere won't see the post.
  class FacebookParams < Model
    attr_accessor :format, :title, :first_comment, :page_id, :link, :alt_text,
                  :made_with_ai, :countries
  end

  # An Instagram account to tag in a post. Images require `x` and `y`; reels
  # and video slides are tagged by username only — Instagram ignores
  # coordinates there. `media_index` picks the carousel slide (0-based).
  class InstagramUserTag < Model
    attr_accessor :username, :x, :y, :media_index
  end

  # `cover_file` is a local path to a cover image, uploaded with the post (the
  # request switches to multipart); a base64 data URL
  # (`data:image/jpeg;base64,...`) is sent as-is. The same holds for TikTok,
  # YouTube and Pinterest.
  #
  # `audio_id` comes from Profiles#instagram_available_audio; it and
  # `audio_volume` / `video_volume` (1-100) need a profile connected via
  # Facebook login. `strip_audio` removes the video's own track (reel, story).
  # `trial_strategy` is "MANUAL" or "SS_PERFORMANCE".
  #
  # `disable_comment` turns comments off right after publishing and
  # `location_id` (the numeric id of a Facebook Page with an address) tags a
  # location — both on posts and reels, not stories. `share_to_feed` is
  # reels-only: `false` publishes to the Reels tab only, not the feed/grid.
  class InstagramParams < Model
    attr_accessor :format, :first_comment, :collaborators, :cover_url,
                  :cover_file, :audio_name, :audio_id, :audio_volume,
                  :video_volume, :strip_audio, :trial_strategy, :thumb_offset,
                  :user_tags, :alt_text, :made_with_ai, :disable_comment,
                  :location_id, :share_to_feed

    def initialize(**attrs)
      @user_tags = nil
      super
      @user_tags = @user_tags&.map do |t|
        t.is_a?(InstagramUserTag) ? t : InstagramUserTag.new(**t.transform_keys(&:to_sym))
      end
    end

    # User tags must reach the wire as plain hashes, with unset coordinates
    # dropped rather than sent as nulls.
    def to_h
      result = super
      tags = result[:user_tags]
      return result if tags.nil?

      result[:user_tags] = tags.map do |t|
        (t.is_a?(Model) ? t.to_h : t).reject { |_, v| v.nil? }
      end
      result
    end
  end

  # `upload_as_draft` sends the video to the creator's TikTok inbox instead of
  # publishing. `cover_url` needs profiles connected after 2026-09-30;
  # `thumb_offset` picks a frame in milliseconds, and `cover_url` wins if both
  # are set.
  class TikTokParams < Model
    attr_accessor :format, :privacy_status, :photo_cover_index, :auto_add_music,
                  :made_with_ai, :disable_comment, :disable_duet, :disable_stitch,
                  :brand_content_toggle, :brand_organic_toggle, :upload_as_draft,
                  :cover_url, :cover_file, :thumb_offset
  end

  # `reshare_urn` reshares a post (e.g. "urn:li:share:123"). `countries` is
  # for organization pages only (up to 25 codes). For format "poll",
  # `poll_question` (140 chars max) and `poll_options` (2-4, 30 chars max
  # each) are required; `poll_duration_days` is 1, 3, 7 (default) or 14.
  # `document_title` is shown above an attached document (defaults to the
  # file name). `first_comment` (1,250 characters or fewer) is posted right
  # after publishing, as the same author; not on polls, and profiles
  # connected before 2026-10-28 must reconnect.
  class LinkedInParams < Model
    attr_accessor :format, :organization_id, :reshare_urn, :alt_text, :countries,
                  :poll_question, :poll_options, :poll_duration_days,
                  :document_title, :first_comment
  end

  # `playlist_id` adds the video to a playlist from Profiles#youtube_playlists.
  class YouTubeParams < Model
    attr_accessor :format, :title, :privacy_status, :cover_url, :cover_file,
                  :made_for_kids, :tags, :category_id, :contains_synthetic_media,
                  :playlist_id
  end

  class PinterestParams < Model
    attr_accessor :format, :title, :board_id, :destination_link, :cover_url,
                  :cover_file, :thumb_offset, :alt_text
  end

  # `topic_tag` is one tag, 50 characters or fewer, without the leading # and
  # with no "." or "&".
  class ThreadsParams < Model
    attr_accessor :format, :alt_text, :topic_tag
  end

  class TwitterParams < Model
    # poll_options and poll_duration_minutes are required when format is
    # "poll": 2-4 options (max 25 chars each), duration 5 to 10080 minutes.
    attr_accessor :format, :alt_text, :poll_options, :poll_duration_minutes
  end

  class BlueskyParams < Model
    attr_accessor :format, :alt_text
  end

  class TelegramParams < Model
    attr_accessor :format, :chat_id, :parse_mode, :disable_link_preview, :disable_notification
  end

  class PlatformParams < Model
    attr_accessor :facebook, :instagram, :tiktok, :linkedin, :youtube,
                  :pinterest, :threads, :twitter, :bluesky, :telegram, :google_business

    def to_h
      result = {}
      %i[facebook instagram tiktok linkedin youtube pinterest threads twitter bluesky telegram google_business].each do |platform|
        value = send(platform)
        next if value.nil?

        params = value.is_a?(Model) ? value.to_h : value
        result[platform] = params.reject { |_, v| v.nil? }
      end
      result
    end
  end

  # --- WhatsApp ---

  class WhatsAppTemplate < Model
    attr_accessor :id, :external_id, :profile_id, :name, :language, :category,
                  :status, :parameter_format, :components,
                  :message_send_ttl_seconds, :rejected_reason, :quality_score,
                  :variable_count, :created_at, :updated_at

    def initialize(**attrs)
      @external_id = nil
      @parameter_format = nil
      @components = []
      @message_send_ttl_seconds = nil
      @rejected_reason = nil
      @quality_score = nil
      @variable_count = 0
      super
      @created_at = parse_time(@created_at)
      @updated_at = parse_time(@updated_at)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end
end
