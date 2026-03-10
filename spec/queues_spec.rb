require "spec_helper"

RSpec.describe PostProxy::Resources::Queues do
  let(:client) { new_client }

  let(:queue_data) do
    {
      id: "q1abc",
      name: "Morning Posts",
      description: "Daily morning content",
      timezone: "America/New_York",
      enabled: true,
      jitter: 10,
      profile_group_id: "pg123",
      timeslots: [
        { id: 1, day: 1, time: "09:00" },
        { id: 2, day: 3, time: "09:00" },
        { id: 3, day: 5, time: "14:00" },
      ],
      posts_count: 5,
    }
  end

  describe "#list" do
    it "returns queues" do
      stub_api(:get, "/post_queues", body: { data: [queue_data] })

      result = client.queues.list
      expect(result).to be_a(PostProxy::ListResponse)
      expect(result.data.length).to eq(1)
      expect(result.data.first).to be_a(PostProxy::Queue)
      expect(result.data.first.id).to eq("q1abc")
      expect(result.data.first.timeslots.length).to eq(3)
    end
  end

  describe "#get" do
    it "returns a single queue" do
      stub_api(:get, "/post_queues/q1abc", body: queue_data)

      queue = client.queues.get("q1abc")
      expect(queue).to be_a(PostProxy::Queue)
      expect(queue.id).to eq("q1abc")
      expect(queue.name).to eq("Morning Posts")
      expect(queue.enabled).to be true
      expect(queue.jitter).to eq(10)
      expect(queue.timeslots.length).to eq(3)
      expect(queue.timeslots.first).to be_a(PostProxy::Timeslot)
    end
  end

  describe "#next_slot" do
    it "returns the next available slot" do
      stub_api(:get, "/post_queues/q1abc/next_slot", body: { next_slot: "2026-03-11T14:00:00Z" })

      result = client.queues.next_slot("q1abc")
      expect(result).to be_a(PostProxy::NextSlotResponse)
      expect(result.next_slot).to eq("2026-03-11T14:00:00Z")
    end
  end

  describe "#create" do
    it "creates a queue with timeslots" do
      stub_api(:post, "/post_queues", body: queue_data)

      queue = client.queues.create(
        "Morning Posts",
        profile_group_id: "pg123",
        description: "Daily morning content",
        timezone: "America/New_York",
        jitter: 10,
        timeslots: [
          { day: 1, time: "09:00" },
          { day: 3, time: "09:00" },
        ]
      )
      expect(queue.id).to eq("q1abc")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/post_queues")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:profile_group_id] == "pg123" &&
            body[:post_queue][:name] == "Morning Posts" &&
            body[:post_queue][:timezone] == "America/New_York" &&
            body[:post_queue][:queue_timeslots_attributes] == [
              { day: 1, time: "09:00" },
              { day: 3, time: "09:00" },
            ]
        }
    end
  end

  describe "#update" do
    it "updates a queue" do
      updated_data = queue_data.merge(enabled: false)
      stub_api(:patch, "/post_queues/q1abc", body: updated_data)

      queue = client.queues.update("q1abc", enabled: false)
      expect(queue.enabled).to be false

      expect(WebMock).to have_requested(:patch, "#{BASE_URL}/api/post_queues/q1abc")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:post_queue][:enabled] == false
        }
    end

    it "updates a queue with timeslot changes" do
      stub_api(:patch, "/post_queues/q1abc", body: queue_data)

      client.queues.update("q1abc", timeslots: [
        { day: 2, time: "10:00" },
        { id: 1, _destroy: true },
      ])

      expect(WebMock).to have_requested(:patch, "#{BASE_URL}/api/post_queues/q1abc")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:post_queue][:queue_timeslots_attributes] == [
            { day: 2, time: "10:00" },
            { id: 1, _destroy: true },
          ]
        }
    end
  end

  describe "#delete" do
    it "deletes a queue" do
      stub_api(:delete, "/post_queues/q1abc", body: { deleted: true })

      result = client.queues.delete("q1abc")
      expect(result).to be_a(PostProxy::DeleteResponse)
      expect(result.deleted).to be true
    end
  end
end
