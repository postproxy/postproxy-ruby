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

RSpec.describe PostProxy::Resources::Chats, "read receipts, typing, WhatsApp" do
  let(:client) { new_client }
  let(:chat_id) { "chat_xyz789" }
  let(:mock_chat) do
    {
      id: "chat_xyz789", profile_id: "prof_wa", platform: "whatsapp",
      external_placement_id: "pn_1", group: false, within_messaging_window: true,
      participant_external_id: "15551234567", created_at: "2026-09-28T00:00:00Z"
    }
  end

  it "creates a WhatsApp chat on a placement" do
    stub = stub_request(:post, "#{BASE_URL}/api/profiles/prof_wa/chats")
      .with(body: { participant_external_id: "15551234567", placement_id: "pn_1" })
      .to_return(status: 200, body: mock_chat.to_json, headers: { "Content-Type" => "application/json" })

    chat = client.chats.create("prof_wa", "15551234567", placement_id: "pn_1")
    expect(stub).to have_been_requested
    expect(chat.external_placement_id).to eq("pn_1")
    expect(chat.group).to be false
    expect(chat.within_messaging_window).to be true
  end

  it "marks a chat read" do
    stub = stub_api(:post, "/chats/#{chat_id}/mark_read", body: mock_chat)

    chat = client.chats.mark_read(chat_id)
    expect(stub).to have_been_requested
    expect(chat).to be_a(PostProxy::Chat)
  end

  it "starts and stops typing" do
    start = stub_api(:post, "/chats/#{chat_id}/start_typing", body: { accepted: true })
    stop = stub_api(:post, "/chats/#{chat_id}/stop_typing", body: { accepted: true })

    started = client.chats.start_typing(chat_id)
    client.chats.stop_typing(chat_id)

    expect(started).to be_a(PostProxy::AcceptedResponse)
    expect(started.accepted).to be true
    [start, stop].each { |s| expect(s).to have_been_requested }
  end

  it "passes thread control to another app" do
    stub = stub_request(:post, "#{BASE_URL}/api/chats/#{chat_id}/pass_thread_control")
      .with(body: { target_app_id: "263902037430900", metadata: "escalated to support" })
      .to_return(status: 200, body: mock_chat.to_json, headers: { "Content-Type" => "application/json" })

    chat = client.chats.pass_thread_control(chat_id, target_app_id: "263902037430900",
      metadata: "escalated to support")
    expect(stub).to have_been_requested
    expect(chat).to be_a(PostProxy::Chat)
    expect(chat.id).to eq("chat_xyz789")
  end

  it "takes, releases and requests thread control" do
    take = stub_request(:post, "#{BASE_URL}/api/chats/#{chat_id}/take_thread_control")
      .with(body: {})
      .to_return(status: 200, body: mock_chat.to_json, headers: { "Content-Type" => "application/json" })
    release = stub_request(:post, "#{BASE_URL}/api/chats/#{chat_id}/release_thread_control")
      .with(body: { metadata: "done" })
      .to_return(status: 200, body: mock_chat.to_json, headers: { "Content-Type" => "application/json" })
    request = stub_api(:post, "/chats/#{chat_id}/request_thread_control", body: mock_chat)

    client.chats.take_thread_control(chat_id)
    client.chats.release_thread_control(chat_id, metadata: "done")
    chat = client.chats.request_thread_control(chat_id)

    expect(chat).to be_a(PostProxy::Chat)
    [take, release, request].each { |s| expect(s).to have_been_requested }
  end

  it "gets the thread owner" do
    stub = stub_api(:get, "/chats/#{chat_id}/thread_owner",
      body: { app_id: "263902037430900", expires_at: "2026-10-28T12:00:00Z" })

    owner = client.chats.thread_owner(chat_id)
    expect(stub).to have_been_requested
    expect(owner).to be_a(PostProxy::ThreadOwner)
    expect(owner.app_id).to eq("263902037430900")
    expect(owner.expires_at).to be_a(Time)
  end

  it "returns an idle thread owner as nils" do
    stub_api(:get, "/chats/#{chat_id}/thread_owner", body: { app_id: nil, expires_at: nil })

    owner = client.chats.thread_owner(chat_id)
    expect(owner.app_id).to be_nil
    expect(owner.expires_at).to be_nil
  end
end
