require "spec_helper"

RSpec.describe PostProxy::Resources::Profiles do
  let(:client) { new_client }

  describe "#list" do
    it "returns profiles" do
      stub_api(:get, "/profiles", body: {
        data: [
          { id: "prof-1", name: "Test Profile", status: "active", platform: "instagram", profile_group_id: "pg-1", post_count: 5 }
        ]
      })

      result = client.profiles.list
      expect(result).to be_a(PostProxy::ListResponse)
      expect(result.data.length).to eq(1)
      expect(result.data.first.id).to eq("prof-1")
      expect(result.data.first.name).to eq("Test Profile")
      expect(result.data.first.platform).to eq("instagram")
    end

    it "sends profile_group_id" do
      stub = stub_api(:get, "/profiles",
        body: { data: [] },
        query: { profile_group_id: "pg-456" }
      )

      client.profiles.list(profile_group_id: "pg-456")
      expect(stub).to have_been_requested
    end
  end

  describe "#get" do
    it "returns a single profile" do
      stub_api(:get, "/profiles/prof-1", body: {
        id: "prof-1", name: "My Profile", status: "active",
        platform: "facebook", profile_group_id: "pg-1",
        expires_at: "2025-12-31T00:00:00Z", post_count: 10
      })

      profile = client.profiles.get("prof-1")
      expect(profile.id).to eq("prof-1")
      expect(profile.expires_at).to be_a(Time)
      expect(profile.post_count).to eq(10)
    end
  end

  describe "#placements" do
    it "returns placements for a profile" do
      stub_api(:get, "/profiles/prof-1/placements", body: {
        data: [
          { id: "feed", name: "Feed" },
          { id: "story", name: "Story" }
        ]
      })

      result = client.profiles.placements("prof-1")
      expect(result.data.length).to eq(2)
      expect(result.data.first.id).to eq("feed")
      expect(result.data.last.name).to eq("Story")
    end
  end

  describe "#assign_placement_to_group" do
    it "moves a placement to another group" do
      stub = stub_api(:patch, "/profiles/prof-1/assign_placement_to_group", body: {
        id: "pl-1", name: "Feed", metadata: {}, profile_group_id: "pg-2"
      })

      result = client.profiles.assign_placement_to_group(
        "prof-1",
        placement_id: "pl-1",
        target_profile_group_id: "pg-2"
      )
      expect(result).to be_a(PostProxy::Placement)
      expect(result.profile_group_id).to eq("pg-2")
      expect(stub.with(
        body: { placement_id: "pl-1", target_profile_group_id: "pg-2" }.to_json
      )).to have_been_requested
    end
  end

  describe "#ice_breakers" do
    it "lists ice breakers" do
      stub_api(:get, "/profiles/prof-1/ice_breakers", body: {
        ice_breakers: [{ question: "What do you do?", payload: "services" }]
      })

      result = client.profiles.ice_breakers("prof-1")
      expect(result).to be_a(PostProxy::IceBreakersResponse)
      expect(result.ice_breakers.length).to eq(1)
      expect(result.ice_breakers.first.question).to eq("What do you do?")
    end
  end

  describe "#set_ice_breakers" do
    it "sets ice breakers" do
      stub = stub_api(:post, "/profiles/prof-1/ice_breakers", body: { success: true })

      result = client.profiles.set_ice_breakers("prof-1", [
        { question: "What do you do?", payload: "services" }
      ])
      expect(result.success).to be true
      expect(stub.with(
        body: { ice_breakers: [{ question: "What do you do?", payload: "services" }] }.to_json
      )).to have_been_requested
    end
  end

  describe "#delete_ice_breakers" do
    it "deletes ice breakers" do
      stub_api(:delete, "/profiles/prof-1/ice_breakers", body: { success: true })

      result = client.profiles.delete_ice_breakers("prof-1")
      expect(result.success).to be true
    end
  end

  describe "#delete" do
    it "deletes a profile" do
      stub_api(:delete, "/profiles/prof-1", body: { success: true })

      result = client.profiles.delete("prof-1")
      expect(result).to be_a(PostProxy::SuccessResponse)
      expect(result.success).to be true
    end
  end

  POST_SYNC = {
    id: "sync456def",
    profile_id: "prof-1",
    kind: "posts",
    trigger: "backfill",
    status: "running",
    started_at: "2026-08-06T09:15:02.000Z",
    completed_at: nil,
    posts_seen: 150,
    posts_imported: 143,
    backfill_from: "2025-01-01T00:00:00.000Z",
    oldest_posted_at: "2025-11-04T18:22:00.000Z",
    error: nil,
    created_at: "2026-08-06T09:15:00.000Z"
  }.freeze

  describe "#backfill_posts" do
    it "starts a backfill" do
      stub = stub_request(:post, "#{BASE_URL}/api/profiles/prof-1/backfill_posts")
        .with(body: { from: "2025-01-01" }.to_json)
        .to_return(status: 202, body: POST_SYNC.merge(status: "pending").to_json,
                   headers: { "Content-Type" => "application/json" })

      sync = client.profiles.backfill_posts("prof-1", from: "2025-01-01")

      expect(sync).to be_a(PostProxy::PostSync)
      expect(sync.id).to eq("sync456def")
      expect(sync.trigger).to eq("backfill")
      expect(sync.status).to eq("pending")
      expect(stub).to have_been_requested
    end

    it "sends an idempotency key" do
      stub = stub_request(:post, "#{BASE_URL}/api/profiles/prof-1/backfill_posts")
        .with(headers: { "Idempotency-Key" => "key-1" })
        .to_return(status: 202, body: POST_SYNC.to_json,
                   headers: { "Content-Type" => "application/json" })

      client.profiles.backfill_posts("prof-1", from: "2025-01-01", idempotency_key: "key-1")
      expect(stub).to have_been_requested
    end

    it "raises ConflictError when a backfill is already running" do
      stub_api(:post, "/profiles/prof-1/backfill_posts", status: 409, body: {
        error: "A posts backfill is already running for this profile",
        profile_sync_id: "sync456def"
      })

      expect { client.profiles.backfill_posts("prof-1", from: "2025-01-01") }
        .to raise_error(PostProxy::ConflictError) { |e|
          expect(e.status_code).to eq(409)
          expect(e.response[:profile_sync_id]).to eq("sync456def")
        }
    end
  end

  describe "#post_syncs" do
    it "lists runs with filters" do
      stub = stub_api(:get, "/profiles/prof-1/post_syncs",
        body: { total: 1, page: 0, per_page: 25, data: [POST_SYNC] },
        query: { trigger: "backfill", status: "running", per_page: "25" }
      )

      result = client.profiles.post_syncs("prof-1", trigger: "backfill", status: "running", per_page: 25)

      expect(result).to be_a(PostProxy::PaginatedResponse)
      expect(result.total).to eq(1)
      expect(result.data.first.posts_imported).to eq(143)
      expect(result.data.first.oldest_posted_at).to be_a(Time)
      expect(stub).to have_been_requested
    end
  end

  describe "#post_sync" do
    it "fetches a single run" do
      stub_api(:get, "/profiles/prof-1/post_syncs/sync456def",
        body: POST_SYNC.merge(status: "completed", completed_at: "2026-08-06T09:40:00.000Z"))

      sync = client.profiles.post_sync("prof-1", "sync456def")

      expect(sync.status).to eq("completed")
      expect(sync.completed_at).to be_a(Time)
    end
  end
end
