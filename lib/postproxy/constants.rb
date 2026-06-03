module PostProxy
  DEFAULT_BASE_URL = "https://api.postproxy.dev"

  PLATFORMS = %w[
    facebook instagram tiktok linkedin youtube twitter threads pinterest bluesky telegram google_business
  ].freeze

  PROFILE_STATUSES = %w[active expired inactive].freeze

  POST_STATUSES = %w[pending draft processing processed scheduled media_processing_failed].freeze

  MEDIA_STATUSES = %w[pending processed failed].freeze

  PLATFORM_POST_STATUSES = %w[pending processing published failed deleted].freeze

  INSTAGRAM_FORMATS = %w[post reel story].freeze
  FACEBOOK_FORMATS = %w[post story reel].freeze
  TIKTOK_FORMATS = %w[video image].freeze
  LINKEDIN_FORMATS = %w[post].freeze
  YOUTUBE_FORMATS = %w[post].freeze
  PINTEREST_FORMATS = %w[pin].freeze
  THREADS_FORMATS = %w[post].freeze
  TWITTER_FORMATS = %w[post].freeze
  BLUESKY_FORMATS = %w[post].freeze
  TELEGRAM_FORMATS = %w[post].freeze

  TIKTOK_PRIVACIES = %w[
    PUBLIC_TO_EVERYONE MUTUAL_FOLLOW_FRIENDS FOLLOWER_OF_CREATOR SELF_ONLY
  ].freeze

  YOUTUBE_PRIVACIES = %w[public unlisted private].freeze

  TELEGRAM_PARSE_MODES = %w[HTML MarkdownV2].freeze

  MESSAGE_DIRECTIONS = %w[inbound outbound].freeze

  MESSAGE_STATUSES = %w[pending published failed_waiting_for_retry failed received].freeze

  WEBHOOK_EVENT_TYPES = %w[
    post.processed
    post.imported
    platform_post.published
    platform_post.failed
    platform_post.failed_waiting_for_retry
    platform_post.insights
    profile.connected
    profile.disconnected
    profile.stats
    media.failed
    comment.created
    profile_comment.created
    message.received
    message.sent
    message.delivered
    message.read
    message.edited
    message.deleted
    message.failed_waiting_for_retry
    message.failed
    reaction.received
  ].freeze
end
