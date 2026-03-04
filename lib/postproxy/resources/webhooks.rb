module PostProxy
  module Resources
    class Webhooks
      def initialize(client)
        @client = client
      end

      def list
        result = @client.request(:get, "/webhooks")
        webhooks = (result[:data] || []).map { |w| Webhook.new(**w) }
        ListResponse.new(data: webhooks)
      end

      def get(id)
        result = @client.request(:get, "/webhooks/#{id}")
        Webhook.new(**result)
      end

      def create(url, events:, description: nil)
        json_body = { url: url, events: events }
        json_body[:description] = description if description

        result = @client.request(:post, "/webhooks", json: json_body)
        Webhook.new(**result)
      end

      def update(id, url: nil, events: nil, enabled: nil, description: nil)
        json_body = {}
        json_body[:url] = url unless url.nil?
        json_body[:events] = events unless events.nil?
        json_body[:enabled] = enabled unless enabled.nil?
        json_body[:description] = description unless description.nil?

        result = @client.request(:patch, "/webhooks/#{id}", json: json_body)
        Webhook.new(**result)
      end

      def delete(id)
        result = @client.request(:delete, "/webhooks/#{id}")
        DeleteResponse.new(**result)
      end

      def deliveries(id, page: nil, per_page: nil)
        params = {}
        params[:page] = page if page
        params[:per_page] = per_page if per_page

        result = @client.request(:get, "/webhooks/#{id}/deliveries", params: params)
        deliveries = (result[:data] || []).map { |d| WebhookDelivery.new(**d) }
        PaginatedResponse.new(
          data: deliveries,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end
    end
  end
end
