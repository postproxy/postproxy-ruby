module PostProxy
  DEFAULT_BASE_URL = "https://api.postproxy.dev"

  PLATFORMS = %w[
    facebook instagram tiktok linkedin youtube twitter threads pinterest
  ].freeze

  PROFILE_STATUSES = %w[active expired inactive].freeze

  POST_STATUSES = %w[pending draft processing processed scheduled media_processing_failed].freeze

  MEDIA_STATUSES = %w[pending processed failed].freeze

  PLATFORM_POST_STATUSES = %w[pending processing published failed deleted].freeze

  INSTAGRAM_FORMATS = %w[post reel story].freeze
  FACEBOOK_FORMATS = %w[post story].freeze
  TIKTOK_FORMATS = %w[video image].freeze
  LINKEDIN_FORMATS = %w[post].freeze
  YOUTUBE_FORMATS = %w[post].freeze
  PINTEREST_FORMATS = %w[pin].freeze
  THREADS_FORMATS = %w[post].freeze
  TWITTER_FORMATS = %w[post].freeze

  TIKTOK_PRIVACIES = %w[
    PUBLIC_TO_EVERYONE MUTUAL_FOLLOW_FRIENDS FOLLOWER_OF_CREATOR SELF_ONLY
  ].freeze

  YOUTUBE_PRIVACIES = %w[public unlisted private].freeze
end
