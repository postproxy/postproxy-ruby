module PostProxy
  module Resources
    class ProfileGroups
      def initialize(client)
        @client = client
      end

      def list
        result = @client.request(:get, "/profile_groups")
        groups = (result[:data] || []).map { |g| ProfileGroup.new(**g) }
        ListResponse.new(data: groups)
      end

      def get(id)
        result = @client.request(:get, "/profile_groups/#{id}")
        ProfileGroup.new(**result)
      end

      def create(name)
        result = @client.request(:post, "/profile_groups", json: { name: name })
        ProfileGroup.new(**result)
      end

      def delete(id)
        result = @client.request(:delete, "/profile_groups/#{id}")
        DeleteResponse.new(**result)
      end

      # OAuth flow. BlueSky and Telegram use their dedicated helpers below.
      def initialize_connection(id, platform:, redirect_url: nil)
        body = { platform: platform }
        body[:redirect_url] = redirect_url if redirect_url
        result = @client.request(:post, "/profile_groups/#{id}/initialize_connection", json: body)
        ConnectionResponse.new(**result)
      end

      def connect_bluesky(id, identifier:, app_password:)
        result = @client.request(:post, "/profile_groups/#{id}/initialize_connection",
          json: { platform: "bluesky", identifier: identifier, app_password: app_password }
        )
        BlueskyConnectionResponse.new(**result)
      end

      # After this call, poll `client.profiles.placements(profile.id)` until non-empty —
      # the bot must be added as administrator to a channel in Telegram first.
      def connect_telegram(id, bot_token:)
        result = @client.request(:post, "/profile_groups/#{id}/initialize_connection",
          json: { platform: "telegram", bot_token: bot_token }
        )
        TelegramConnectionResponse.new(**result)
      end
    end
  end
end
