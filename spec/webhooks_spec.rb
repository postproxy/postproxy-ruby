require "spec_helper"

RSpec.describe PostProxy::Resources::Webhooks do
  let(:client) { new_client }

  let(:webhook_data) do
    {
      id: "wh-1",
      url: "https://example.com/webhook",
      events: ["post.published", "post.failed"],
      enabled: true,
      description: "Test webhook",
      secret: "whsec_test123",
      created_at: "2025-01-01T00:00:00Z",
      updated_at: "2025-01-01T00:00:00Z",
    }
  end

  let(:delivery_data) do
    {
      id: "del-1",
      event_id: "evt-1",
      event_type: "post.published",
      response_status: 200,
      attempt_number: 1,
      success: true,
      attempted_at: "2025-01-01T00:00:00Z",
      created_at: "2025-01-01T00:00:00Z",
    }
  end

  describe "#list" do
    it "returns webhooks" do
      stub_api(:get, "/webhooks", body: { data: [webhook_data] })

      result = client.webhooks.list
      expect(result).to be_a(PostProxy::ListResponse)
      expect(result.data.length).to eq(1)
      expect(result.data.first).to be_a(PostProxy::Webhook)
      expect(result.data.first.id).to eq("wh-1")
    end
  end

  describe "#get" do
    it "returns a single webhook" do
      stub_api(:get, "/webhooks/wh-1", body: webhook_data)

      webhook = client.webhooks.get("wh-1")
      expect(webhook).to be_a(PostProxy::Webhook)
      expect(webhook.id).to eq("wh-1")
      expect(webhook.events).to eq(["post.published", "post.failed"])
      expect(webhook.enabled).to be true
    end
  end

  describe "#create" do
    it "creates a webhook" do
      stub_api(:post, "/webhooks", body: webhook_data)

      webhook = client.webhooks.create(
        "https://example.com/webhook",
        events: ["post.published", "post.failed"],
        description: "Test webhook"
      )
      expect(webhook.id).to eq("wh-1")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/webhooks")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:url] == "https://example.com/webhook" &&
            body[:events] == ["post.published", "post.failed"] &&
            body[:description] == "Test webhook"
        }
    end
  end

  describe "#update" do
    it "updates a webhook" do
      updated_data = webhook_data.merge(enabled: false)
      stub_api(:patch, "/webhooks/wh-1", body: updated_data)

      webhook = client.webhooks.update("wh-1", enabled: false)
      expect(webhook.enabled).to be false

      expect(WebMock).to have_requested(:patch, "#{BASE_URL}/api/webhooks/wh-1")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:enabled] == false
        }
    end
  end

  describe "#delete" do
    it "deletes a webhook" do
      stub_api(:delete, "/webhooks/wh-1", body: { deleted: true })

      result = client.webhooks.delete("wh-1")
      expect(result).to be_a(PostProxy::DeleteResponse)
      expect(result.deleted).to be true
    end
  end

  describe "#deliveries" do
    it "returns paginated deliveries" do
      stub_api(:get, "/webhooks/wh-1/deliveries",
        body: { data: [delivery_data], total: 1, page: 1, per_page: 10 },
        query: { page: "1", per_page: "10" }
      )

      result = client.webhooks.deliveries("wh-1", page: 1, per_page: 10)
      expect(result).to be_a(PostProxy::PaginatedResponse)
      expect(result.data.length).to eq(1)
      expect(result.data.first).to be_a(PostProxy::WebhookDelivery)
      expect(result.data.first.id).to eq("del-1")
      expect(result.data.first.success).to be true
    end
  end
end

RSpec.describe PostProxy::WebhookSignature do
  let(:payload) { '{"event":"post.published","data":{"id":"post-1"}}' }
  let(:secret) { "whsec_test123" }
  let(:valid_signature) { "t=1234567890,v1=c8e99efbb07ac8e3152c02dd8d83e8ddb803ae8fb001d9e1ab42fb0b1f405ef2" }

  it "verifies a valid signature" do
    expect(PostProxy::WebhookSignature.verify(payload, valid_signature, secret)).to be true
  end

  it "rejects an invalid signature" do
    expect(PostProxy::WebhookSignature.verify(payload, "t=1234567890,v1=invalid", secret)).to be false
  end

  it "rejects with wrong secret" do
    expect(PostProxy::WebhookSignature.verify(payload, valid_signature, "wrong_secret")).to be false
  end

  it "rejects missing timestamp" do
    expect(PostProxy::WebhookSignature.verify(payload, "v1=abc123", secret)).to be false
  end
end

RSpec.describe "New model fields" do
  describe PostProxy::Webhook do
    it "parses webhook attributes" do
      webhook = PostProxy::Webhook.new(
        id: "wh-1",
        url: "https://example.com/webhook",
        events: ["post.published"],
        enabled: true,
        secret: "whsec_test",
        created_at: "2025-01-01T00:00:00Z",
        updated_at: "2025-01-01T00:00:00Z"
      )
      expect(webhook.id).to eq("wh-1")
      expect(webhook.secret).to eq("whsec_test")
      expect(webhook.enabled).to be true
      expect(webhook.created_at).to be_a(Time)
    end
  end

  describe PostProxy::WebhookDelivery do
    it "parses delivery attributes" do
      delivery = PostProxy::WebhookDelivery.new(
        id: "del-1",
        event_id: "evt-1",
        event_type: "post.published",
        response_status: 200,
        attempt_number: 1,
        success: true,
        attempted_at: "2025-01-01T00:00:00Z",
        created_at: "2025-01-01T00:00:00Z"
      )
      expect(delivery.id).to eq("del-1")
      expect(delivery.event_type).to eq("post.published")
      expect(delivery.response_status).to eq(200)
      expect(delivery.success).to be true
    end
  end

  describe PostProxy::Post do
    it "parses post with media and thread" do
      post = PostProxy::Post.new(
        id: "post-1",
        body: "Hello",
        status: "media_processing_failed",
        created_at: "2025-01-01T00:00:00Z",
        media: [
          { id: "m-1", status: "processed", content_type: "image/jpeg", url: "https://cdn.example.com/img.jpg" }
        ],
        thread: [
          { id: "t-1", body: "Thread reply", media: [] }
        ]
      )
      expect(post.status).to eq("media_processing_failed")
      expect(post.media.length).to eq(1)
      expect(post.media.first).to be_a(PostProxy::Media)
      expect(post.media.first.status).to eq("processed")
      expect(post.thread.length).to eq(1)
      expect(post.thread.first).to be_a(PostProxy::ThreadChild)
      expect(post.thread.first.body).to eq("Thread reply")
    end
  end

  describe PostProxy::YouTubeParams do
    it "includes made_for_kids" do
      params = PostProxy::YouTubeParams.new(title: "Test", privacy_status: "public", made_for_kids: true)
      h = params.to_h
      expect(h[:made_for_kids]).to be true
    end
  end
end
