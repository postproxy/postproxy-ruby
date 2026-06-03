require "spec_helper"

RSpec.describe PostProxy::Resources::Chats do
  let(:client) { new_client }
  let(:profile_id) { "prof_abc123" }
  let(:chat_id) { "chat_xyz789" }

  let(:mock_chat) do
    {
      id: "chat_xyz789",
      profile_id: "prof_abc123",
      platform: "instagram",
      participant_external_id: "igsid_8675309",
      participant_username: "jane_doe",
      participant_name: "Jane Doe",
      participant_avatar_url: "https://storage.postproxy.dev/x.jpg",
      external_conversation_id: nil,
      last_inbound_at: "2026-05-31T14:02:00.000Z",
      last_outbound_at: "2026-05-31T15:10:00.000Z",
      last_message_at: "2026-05-31T15:10:00.000Z",
      metadata: { is_verified_user: false, follower_count: 482 },
      created_at: "2026-04-12T08:00:00.000Z",
    }
  end

  describe "#list" do
    it "returns paginated chats" do
      stub_api(:get, "/profiles/#{profile_id}/chats",
        body: { data: [mock_chat], total: 1, page: 0, per_page: 20 },
        query: { per_page: "20" })

      result = client.chats.list(profile_id, per_page: 20)
      expect(result).to be_a(PostProxy::PaginatedResponse)
      expect(result.total).to eq(1)
      chat = result.data.first
      expect(chat).to be_a(PostProxy::Chat)
      expect(chat.id).to eq("chat_xyz789")
      expect(chat.participant_username).to eq("jane_doe")
      expect(chat.metadata[:follower_count]).to eq(482)
      expect(chat.last_message_at).to be_a(Time)
    end

    it "supports before/after params" do
      stub_api(:get, "/profiles/#{profile_id}/chats",
        body: { data: [], total: 0, page: 0, per_page: 20 },
        query: { before: "2026-05-31T00:00:00Z", after: "2026-05-01T00:00:00Z" })

      result = client.chats.list(profile_id,
        before: "2026-05-31T00:00:00Z", after: "2026-05-01T00:00:00Z")
      expect(result.total).to eq(0)
    end
  end

  describe "#create" do
    it "creates (or finds) a chat" do
      stub_api(:post, "/profiles/#{profile_id}/chats", body: mock_chat)

      chat = client.chats.create(profile_id, "igsid_8675309", participant_username: "jane_doe")
      expect(chat).to be_a(PostProxy::Chat)
      expect(chat.id).to eq("chat_xyz789")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/profiles/#{profile_id}/chats")
        .with { |req|
          body = JSON.parse(req.body)
          body["participant_external_id"] == "igsid_8675309" && body["participant_username"] == "jane_doe"
        }
    end
  end

  describe "#get" do
    it "returns a single chat" do
      stub_api(:get, "/chats/#{chat_id}", body: mock_chat)

      chat = client.chats.get(chat_id)
      expect(chat).to be_a(PostProxy::Chat)
      expect(chat.id).to eq("chat_xyz789")
    end
  end

  describe "#archive" do
    it "archives a chat" do
      stub_api(:post, "/chats/#{chat_id}/archive", body: mock_chat.merge(archived: true))

      chat = client.chats.archive(chat_id)
      expect(chat.archived).to be true
    end
  end

  describe "#unarchive" do
    it "unarchives a chat" do
      stub_api(:delete, "/chats/#{chat_id}/archive", body: mock_chat.merge(archived: false))

      chat = client.chats.unarchive(chat_id)
      expect(chat.archived).to be false
    end
  end
end
