module PostProxy
  module Resources
    # Manage profile-group-scoped API keys. Requires an account-wide key.
    class ApiKeys
      def initialize(client)
        @client = client
      end

      def list
        result = @client.request(:get, "/api_keys")
        keys = (result[:data] || []).map { |k| ApiKey.new(**k) }
        ListResponse.new(data: keys)
      end

      # The returned `token` is shown only once.
      def create(name, profile_group_id:, idempotency_key: nil)
        result = @client.request(:post, "/api_keys",
          json: { name: name, profile_group_id: profile_group_id },
          idempotency_key: idempotency_key
        )
        ApiKey.new(**result)
      end

      def delete(id, idempotency_key: nil)
        result = @client.request(:delete, "/api_keys/#{id}", idempotency_key: idempotency_key)
        DeleteResponse.new(**result)
      end
    end
  end
end
