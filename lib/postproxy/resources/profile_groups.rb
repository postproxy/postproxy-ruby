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

      def initialize_connection(id, platform:, redirect_url:)
        result = @client.request(:post, "/profile_groups/#{id}/initialize_connection",
          json: { platform: platform, redirect_url: redirect_url }
        )
        ConnectionResponse.new(**result)
      end
    end
  end
end
