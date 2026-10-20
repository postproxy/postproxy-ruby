module PostProxy
  DEFAULT_BASE_URL = "https://api.postproxy.dev"

  PLATFORMS = %w[
    facebook instagram tiktok linkedin youtube twitter threads pinterest bluesky telegram google_business whatsapp
  ].freeze

  PROFILE_STATUSES = %w[active expired inactive].freeze

  POST_STATUSES = %w[pending draft processing processed scheduled media_processing_failed].freeze

  MEDIA_STATUSES = %w[pending processed failed].freeze

  PLATFORM_POST_STATUSES = %w[pending processing published failed deleted].freeze

  INSTAGRAM_FORMATS = %w[post reel story].freeze
  FACEBOOK_FORMATS = %w[post story reel].freeze
  TIKTOK_FORMATS = %w[video image].freeze
  LINKEDIN_FORMATS = %w[post poll].freeze
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

  INSTAGRAM_TRIAL_STRATEGIES = %w[MANUAL SS_PERFORMANCE].freeze

  INSTAGRAM_AUDIO_TYPES = %w[music original_sound].freeze

  # Facebook and Instagram profiles connect through Facebook login; WhatsApp
  # through the Cloud API or the WhatsApp Business app.
  CONNECTION_ONBOARDINGS = %w[instagram facebook api business_app].freeze

  DAILY_STATS_ATTRIBUTIONS = %w[received publish].freeze

  PROFILE_INACTIVE_REASONS = %w[network_taken].freeze

  POST_SYNC_TRIGGERS = %w[connect scheduled backfill].freeze

  POST_SYNC_STATUSES = %w[pending running completed failed].freeze

  MESSAGE_DIRECTIONS = %w[inbound outbound].freeze

  MESSAGE_STATUSES = %w[pending published failed_waiting_for_retry failed received].freeze

  WEBHOOK_EVENT_TYPES = %w[
    post.processed
    post.imported
    platform_post.published
    platform_post.failed
    platform_post.failed_waiting_for_retry
    platform_post.edited
    platform_post.edit_failed
    platform_post.insights
    profile.connected
    profile.disconnected
    profile.stats
    profile.placements_synced
    placement.orphaned
    placement.restored
    media.failed
    comment.created
    comment.failed
    comment.failed_waiting_for_retry
    comment.delivery_unconfirmed
    comment.edited
    comment.edit_failed
    profile_comment.created
    profile_comment.failed
    profile_comment.failed_waiting_for_retry
    profile_comment.deleted
    message.received
    message.sent
    message.delivered
    message.read
    message.edited
    message.deleted
    message.failed_waiting_for_retry
    message.failed
    reaction.received
    referral.received
    message_template.status_updated
    message_template.category_updated
    placement.name_status_updated
    placement.quality_updated
    whatsapp.automatic_event
  ].freeze
end
