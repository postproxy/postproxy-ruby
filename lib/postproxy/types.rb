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

  class Post < Model
    attr_accessor :id, :body, :status, :scheduled_at, :created_at, :platforms

    def initialize(**attrs)
      @scheduled_at = nil
      @platforms = []
      super
      @scheduled_at = parse_time(@scheduled_at)
      @created_at = parse_time(@created_at)
      @platforms = (@platforms || []).map do |p|
        p.is_a?(PlatformResult) ? p : PlatformResult.new(**p.transform_keys(&:to_sym))
      end
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
    attr_accessor :format, :first_comment, :page_id
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
    attr_accessor :format, :title, :privacy_status, :cover_url
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
