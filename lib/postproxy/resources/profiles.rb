module PostProxy
  module Resources
    class Profiles
      def initialize(client)
        @client = client
      end

      def list(profile_group_id: nil)
        result = @client.request(:get, "/profiles", profile_group_id: profile_group_id)
        profiles = (result[:data] || []).map { |p| Profile.new(**p) }
        ListResponse.new(data: profiles)
      end

      def get(id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}", profile_group_id: profile_group_id)
        Profile.new(**result)
      end

      def placements(id, profile_group_id: nil)
        result = @client.request(:get, "/profiles/#{id}/placements", profile_group_id: profile_group_id)
        items = (result[:data] || []).map { |p| Placement.new(**p) }
        ListResponse.new(data: items)
      end

      def delete(id, profile_group_id: nil)
        result = @client.request(:delete, "/profiles/#{id}", profile_group_id: profile_group_id)
        SuccessResponse.new(**result)
      end
    end
  end
end
