module PostProxy
  module Resources
    class Queues
      def initialize(client)
        @client = client
      end

      def list(profile_group_id: nil)
        result = @client.request(:get, "/post_queues", profile_group_id: profile_group_id)
        queues = (result[:data] || []).map { |q| Queue.new(**q) }
        ListResponse.new(data: queues)
      end

      def get(id)
        result = @client.request(:get, "/post_queues/#{id}")
        Queue.new(**result)
      end

      def next_slot(id)
        result = @client.request(:get, "/post_queues/#{id}/next_slot")
        NextSlotResponse.new(**result)
      end

      def create(name, profile_group_id:, description: nil, timezone: nil, jitter: nil, timeslots: nil)
        post_queue = { name: name }
        post_queue[:description] = description if description
        post_queue[:timezone] = timezone if timezone
        post_queue[:jitter] = jitter unless jitter.nil?
        post_queue[:queue_timeslots_attributes] = timeslots if timeslots

        json_body = {
          profile_group_id: profile_group_id,
          post_queue: post_queue,
        }

        result = @client.request(:post, "/post_queues", json: json_body)
        Queue.new(**result)
      end

      def update(id, name: nil, description: nil, timezone: nil, enabled: nil, jitter: nil, timeslots: nil)
        post_queue = {}
        post_queue[:name] = name unless name.nil?
        post_queue[:description] = description unless description.nil?
        post_queue[:timezone] = timezone unless timezone.nil?
        post_queue[:enabled] = enabled unless enabled.nil?
        post_queue[:jitter] = jitter unless jitter.nil?
        post_queue[:queue_timeslots_attributes] = timeslots if timeslots

        json_body = { post_queue: post_queue }

        result = @client.request(:patch, "/post_queues/#{id}", json: json_body)
        Queue.new(**result)
      end

      def delete(id)
        result = @client.request(:delete, "/post_queues/#{id}")
        DeleteResponse.new(**result)
      end
    end
  end
end
