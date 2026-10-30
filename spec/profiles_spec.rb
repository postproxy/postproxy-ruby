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

RSpec.describe PostProxy::Resources::Profiles, "stats, mentions, chat syncs" do
  let(:client) { new_client }

  def json_response(body)
    { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  it "fetches daily stats with attribution" do
    stub = stub_api(:get, "/profiles/p1/daily_stats",
      body: { data: {
        profile_id: "p1", platform: "instagram", placement_id: "pl1", attribution: "publish",
        from: "2026-09-01", to: "2026-09-30", data_timezone: "UTC",
        records: [{ date: "2026-09-01", impressions: 10, platform_stats: nil }],
        metrics: { impressions: { label: "Impressions" } }
      } },
      query: { placement_id: "pl1", from: "2026-09-01", to: "2026-09-30", attribution: "publish" })

    result = client.profiles.daily_stats("p1",
      placement_id: "pl1", from: "2026-09-01", to: "2026-09-30", attribution: "publish")
    expect(stub).to have_been_requested
    expect(result).to be_a(PostProxy::DailyStatsResponse)
    expect(result.data).to be_a(PostProxy::DailyStats)
    expect(result.data.attribution).to eq("publish")
    record = result.data.records.first
    expect(record).to be_a(PostProxy::DailyStatsRecord)
    expect(record.date).to eq("2026-09-01")
    expect(record[:impressions]).to eq(10)
    expect(record.values).to eq(impressions: 10)
  end

  it "fetches follower history" do
    stub = stub_api(:get, "/profiles/p1/follower_history",
      body: { data: { profile_id: "p1", records: [{ date: "2026-09-01", followers_total: 120 }] } },
      query: { from: "2026-09-01" })

    result = client.profiles.follower_history("p1", from: "2026-09-01")
    expect(stub).to have_been_requested
    expect(result.data.records.first).to be_a(PostProxy::FollowerHistoryRecord)
    expect(result.data.records.first.followers_total).to eq(120)
  end

  it "fetches participant status" do
    stub_api(:get, "/profiles/p1/participants/igsid_1", body: { is_verified_user: true, fetched_at: "x" })

    result = client.profiles.participant_status("p1", "igsid_1")
    expect(result).to be_a(PostProxy::ParticipantStatus)
    expect(result.is_verified_user).to be true
  end

  it "resolves a LinkedIn mention" do
    stub = stub_api(:get, "/profiles/p1/resolve_mention",
      body: { urn: "urn:li:organization:1", type: "organization", name: "Acme", vanity_name: "acme" },
      query: { url: "https://www.linkedin.com/company/acme" })

    result = client.profiles.resolve_mention("p1", "https://www.linkedin.com/company/acme")
    expect(stub).to have_been_requested
    expect(result).to be_a(PostProxy::ResolvedMention)
    expect(result.urn).to eq("urn:li:organization:1")
  end

  it "searches Instagram audio" do
    stub = stub_api(:get, "/profiles/p1/instagram/available_audio",
      body: { data: [{ id: "a1" }] }, query: { audio_type: "music", search_query: "summer" })

    result = client.profiles.instagram_available_audio("p1", audio_type: "music", search_query: "summer")
    expect(stub).to have_been_requested
    expect(result[:data].first[:id]).to eq("a1")
  end

  it "reads and updates a Facebook Page" do
    read = stub_api(:get, "/profiles/p1/facebook/page", body: { about: "Hi" },
      query: { page_id: "page_1", fields: "about,website" })
    update = stub_request(:patch, "#{BASE_URL}/api/profiles/p1/facebook/update_page")
      .with(body: { about: "New about", page_id: "page_1" })
      .to_return(json_response({ success: true }))

    page = client.profiles.facebook_page("p1", "page_1", fields: "about,website")
    client.profiles.update_facebook_page("p1", "page_1", { about: "New about" })

    expect(page[:about]).to eq("Hi")
    [read, update].each { |s| expect(s).to have_been_requested }
  end

  it "moves a profile to another group" do
    stub = stub_request(:patch, "#{BASE_URL}/api/profiles/p1/assign_to_group")
      .with(body: { target_profile_group_id: "pg_2" })
      .to_return(json_response({ id: "p1", name: "Acme", status: "active", platform: "instagram",
                                 profile_group_id: "pg_2" }))

    profile = client.profiles.assign_to_group("p1", "pg_2")
    expect(stub).to have_been_requested
    expect(profile).to be_a(PostProxy::Profile)
    expect(profile.profile_group_id).to eq("pg_2")
  end

  it "starts and lists chat backfills" do
    sync = { id: "cs1", profile_id: "p1", kind: "chats", trigger: "backfill", status: "pending",
             chats_seen: 0, messages_imported: 0, backfill_from: "2026-01-01T00:00:00Z",
             created_at: "2026-09-01T00:00:00Z" }
    start = stub_request(:post, "#{BASE_URL}/api/profiles/p1/backfill_chats")
      .with(body: { from: "2026-01-01T00:00:00Z" })
      .to_return(json_response(sync))
    list = stub_api(:get, "/profiles/p1/chat_syncs",
      body: { total: 1, page: 1, per_page: 5, data: [sync] }, query: { status: "running", per_page: "5" })
    one = stub_api(:get, "/profiles/p1/chat_syncs/cs1", body: sync)

    run = client.profiles.backfill_chats("p1", from: "2026-01-01T00:00:00Z")
    runs = client.profiles.chat_syncs("p1", status: "running", per_page: 5)
    client.profiles.chat_sync("p1", "cs1")

    expect(run).to be_a(PostProxy::ChatSync)
    expect(run.chats_seen).to eq(0)
    expect(run.backfill_from).to be_a(Time)
    expect(runs).to be_a(PostProxy::PaginatedResponse)
    expect(runs.data.first).to be_a(PostProxy::ChatSync)
    [start, list, one].each { |s| expect(s).to have_been_requested }
  end

  it "lists, accepts and declines Instagram collaboration invites" do
    list = stub_api(:get, "/profiles/p1/instagram/collaboration_invites",
      body: {
        collaboration_invites: [
          { media_id: "1789", media_owner_username: "partner_brand", caption: "Collab", media_url: "https://x" }
        ],
        next_cursor: nil
      },
      query: { after: "cur_1" })
    accept = stub_request(:post, "#{BASE_URL}/api/profiles/p1/instagram/accept_collaboration_invite")
      .with(body: { media_id: "1789" })
      .to_return(json_response({ accepted: true, media_id: "1789" }))
    decline = stub_request(:post, "#{BASE_URL}/api/profiles/p1/instagram/decline_collaboration_invite")
      .with(body: { media_id: "1790" })
      .to_return(json_response({ declined: true, media_id: "1790" }))

    invites = client.profiles.instagram_collaboration_invites("p1", after: "cur_1")
    accepted = client.profiles.accept_instagram_collaboration_invite("p1", "1789")
    declined = client.profiles.decline_instagram_collaboration_invite("p1", "1790")

    expect(invites).to be_a(PostProxy::InstagramCollaborationInvitesResponse)
    expect(invites.collaboration_invites.first).to be_a(PostProxy::InstagramCollaborationInvite)
    expect(invites.collaboration_invites.first.media_owner_username).to eq("partner_brand")
    expect(invites.next_cursor).to be_nil
    expect(accepted).to be_a(PostProxy::InstagramCollaborationInviteResult)
    expect(accepted.accepted).to be true
    expect(declined.declined).to be true
    expect(declined.media_id).to eq("1790")
    [list, accept, decline].each { |s| expect(s).to have_been_requested }
  end

  it "creates and deletes Pinterest boards" do
    create = stub_request(:post, "#{BASE_URL}/api/profiles/p1/pinterest/create_board")
      .with(body: { name: "Summer Recipes", description: "Light dinners", privacy: "PROTECTED" })
      .to_return(json_response({ id: "1022", name: "Summer Recipes", avatar_url: nil, metadata: {} }))
    del = stub_api(:delete, "/profiles/p1/pinterest/delete_board",
      body: { deleted: true, board_id: "1022" }, query: { board_id: "1022" })

    board = client.profiles.create_pinterest_board("p1", "Summer Recipes",
      description: "Light dinners", privacy: "PROTECTED")
    result = client.profiles.delete_pinterest_board("p1", "1022")

    expect(board).to be_a(PostProxy::Placement)
    expect(board.id).to eq("1022")
    expect(result).to be_a(PostProxy::PinterestBoardDeleted)
    expect(result.deleted).to be true
    expect(result.board_id).to eq("1022")
    [create, del].each { |s| expect(s).to have_been_requested }
  end

  it "manages YouTube playlists" do
    playlist = {
      id: "PL1", title: "Tutorials", description: "", privacy_status: "public",
      item_count: 3, thumbnail_url: nil, published_at: "2026-03-14T09:21:00.000Z"
    }
    list = stub_api(:get, "/profiles/p1/youtube/playlists",
      body: { data: [playlist], next_page_token: nil }, query: { page_token: "tok" })
    create = stub_request(:post, "#{BASE_URL}/api/profiles/p1/youtube/create_playlist")
      .with(body: { title: "Tutorials", privacy_status: "unlisted" })
      .to_return(json_response(playlist))
    update = stub_request(:patch, "#{BASE_URL}/api/profiles/p1/youtube/update_playlist")
      .with(body: { playlist_id: "PL1", description: "" })
      .to_return(json_response(playlist))
    del = stub_api(:delete, "/profiles/p1/youtube/delete_playlist",
      body: { deleted: true, playlist_id: "PL1" }, query: { playlist_id: "PL1" })

    page = client.profiles.youtube_playlists("p1", page_token: "tok")
    created = client.profiles.create_youtube_playlist("p1", "Tutorials", privacy_status: "unlisted")
    client.profiles.update_youtube_playlist("p1", "PL1", description: "")
    deleted = client.profiles.delete_youtube_playlist("p1", "PL1")

    expect(page).to be_a(PostProxy::YouTubePlaylistsResponse)
    expect(page.data.first).to be_a(PostProxy::YouTubePlaylist)
    expect(page.data.first.item_count).to eq(3)
    expect(page.data.first.published_at).to be_a(Time)
    expect(page.next_page_token).to be_nil
    expect(created.id).to eq("PL1")
    expect(deleted).to be_a(PostProxy::YouTubePlaylistDeleted)
    expect(deleted.playlist_id).to eq("PL1")
    [list, create, update, del].each { |s| expect(s).to have_been_requested }
  end
end
