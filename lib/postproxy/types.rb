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
    attr_accessor :id, :name, :status, :platform, :profile_group_id, :expires_at, :post_count

    def initialize(**attrs)
      @expires_at = nil
      @post_count = 0
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

  class PlatformResult < Model
    attr_accessor :platform, :status, :params, :error, :attempted_at, :insights

    def initialize(**attrs)
      @params = nil
      @error = nil
      @attempted_at = nil
      @insights = nil
      super
      @attempted_at = parse_time(@attempted_at)
      @insights = Insights.new(**@insights) if @insights.is_a?(Hash)
    end

    private

    def parse_time(value)
      return nil if value.nil?
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end

  class Media < Model
    attr_accessor :id, :status, :error_message, :content_type, :source_url, :url

    def initialize(**attrs)
      @error_message = nil
      @source_url = nil
      @url = nil
      super
    end
  end

  class ThreadChild < Model
    attr_accessor :id, :body, :media

    def initialize(**attrs)
      @media = []
      super
      @media = (@media || []).map do |m|
        m.is_a?(Media) ? m : Media.new(**m.transform_keys(&:to_sym))
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
    attr_accessor :id, :body, :status, :scheduled_at, :created_at, :media, :platforms, :thread,
                  :queue_id, :queue_priority

    def initialize(**attrs)
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
    attr_accessor :id, :name
  end

  class StatsRecord < Model
    attr_accessor :stats, :recorded_at

    def initialize(**attrs)
      @stats = {}
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

  class Comment < Model
    attr_accessor :id, :external_id, :body, :status, :author_username,
                  :author_avatar_url, :author_external_id, :parent_external_id,
                  :like_count, :is_hidden, :permalink, :platform_data,
                  :posted_at, :created_at, :replies

    def initialize(**attrs)
      @external_id = nil
      @author_avatar_url = nil
      @author_external_id = nil
      @parent_external_id = nil
      @like_count = 0
      @is_hidden = false
      @permalink = nil
      @platform_data = nil
      @replies = []
      super
      @posted_at = parse_time(@posted_at)
      @created_at = parse_time(@created_at)
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

  class AcceptedResponse < Model
    attr_accessor :accepted
  end

  class DeleteResponse < Model
    attr_accessor :deleted
  end

  class SuccessResponse < Model
    attr_accessor :success
  end

  class ConnectionResponse < Model
    attr_accessor :url, :success
  end

  # Platform-specific parameter structs

  class FacebookParams < Model
    attr_accessor :format, :title, :first_comment, :page_id
  end

  class InstagramParams < Model
    attr_accessor :format, :first_comment, :collaborators, :cover_url,
                  :audio_name, :trial_strategy, :thumb_offset
  end

  class TikTokParams < Model
    attr_accessor :format, :privacy_status, :photo_cover_index, :auto_add_music,
                  :made_with_ai, :disable_comment, :disable_duet, :disable_stitch,
                  :brand_content_toggle, :brand_organic_toggle
  end

  class LinkedInParams < Model
    attr_accessor :format, :organization_id
  end

  class YouTubeParams < Model
    attr_accessor :format, :title, :privacy_status, :cover_url, :made_for_kids,
                  :tags, :category_id, :contains_synthetic_media
  end

  class PinterestParams < Model
    attr_accessor :format, :title, :board_id, :destination_link, :cover_url, :thumb_offset
  end

  class ThreadsParams < Model
    attr_accessor :format
  end

  class TwitterParams < Model
    attr_accessor :format
  end

  class PlatformParams < Model
    attr_accessor :facebook, :instagram, :tiktok, :linkedin, :youtube,
                  :pinterest, :threads, :twitter

    def to_h
      result = {}
      %i[facebook instagram tiktok linkedin youtube pinterest threads twitter].each do |platform|
        value = send(platform)
        next if value.nil?

        params = value.is_a?(Model) ? value.to_h : value
        result[platform] = params.reject { |_, v| v.nil? }
      end
      result
    end
  end
end
