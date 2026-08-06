require "spec_helper"

RSpec.describe PostProxy::Resources::Comments do
  let(:client) { new_client }
  let(:post_id) { "post1" }
  let(:profile_id) { "prof1" }
  let(:comment_id) { "cmt_abc123" }

  let(:mock_reply) do
    {
      id: "cmt_def456",
      external_id: "17858893269123457",
      body: "Thanks!",
      status: "synced",
      author_username: "author",
      author_avatar_url: nil,
      author_external_id: "67890",
      parent_external_id: "17858893269123456",
      like_count: 1,
      is_hidden: false,
      permalink: nil,
      platform_data: nil,
      posted_at: "2026-03-25T10:05:00Z",
      created_at: "2026-03-25T10:05:00Z",
      replies: [],
    }
  end

  let(:mock_comment) do
    {
      id: "cmt_abc123",
      external_id: "17858893269123456",
      body: "Great post!",
      status: "synced",
      author_username: "someuser",
      author_avatar_url: nil,
      author_external_id: "12345",
      parent_external_id: nil,
      like_count: 3,
      is_hidden: false,
      permalink: nil,
      platform_data: nil,
      posted_at: "2026-03-25T10:00:00Z",
      created_at: "2026-03-25T10:01:00Z",
      replies: [mock_reply],
    }
  end

  describe "#list" do
    it "returns paginated comments" do
      stub_api(:get, "/posts/#{post_id}/comments",
        body: { data: [mock_comment], total: 1, page: 0, per_page: 20 },
        query: { profile_id: profile_id })

      result = client.comments.list(post_id, profile_id: profile_id)
      expect(result).to be_a(PostProxy::PaginatedResponse)
      expect(result.total).to eq(1)
      expect(result.data.length).to eq(1)
      expect(result.data.first).to be_a(PostProxy::Comment)
      expect(result.data.first.id).to eq("cmt_abc123")
      expect(result.data.first.body).to eq("Great post!")
      expect(result.data.first.replies.length).to eq(1)
      expect(result.data.first.replies.first.id).to eq("cmt_def456")
    end

    it "supports pagination params" do
      stub_api(:get, "/posts/#{post_id}/comments",
        body: { data: [], total: 42, page: 2, per_page: 10 },
        query: { profile_id: profile_id, page: "2", per_page: "10" })

      result = client.comments.list(post_id, profile_id: profile_id, page: 2, per_page: 10)
      expect(result.total).to eq(42)
      expect(result.page).to eq(2)
    end
  end

  describe "#get" do
    it "returns a single comment" do
      stub_api(:get, "/posts/#{post_id}/comments/#{comment_id}",
        body: mock_comment,
        query: { profile_id: profile_id })

      comment = client.comments.get(post_id, comment_id, profile_id: profile_id)
      expect(comment).to be_a(PostProxy::Comment)
      expect(comment.id).to eq("cmt_abc123")
      expect(comment.body).to eq("Great post!")
      expect(comment.like_count).to eq(3)
      expect(comment.replies.length).to eq(1)
    end
  end

  describe "#create" do
    it "creates a comment" do
      created = mock_comment.merge(id: "cmt_new", body: "Nice!", status: "pending", external_id: nil, replies: [])
      stub_api(:post, "/posts/#{post_id}/comments",
        body: created,
        query: { profile_id: profile_id })

      comment = client.comments.create(post_id, "Nice!", profile_id: profile_id)
      expect(comment).to be_a(PostProxy::Comment)
      expect(comment.id).to eq("cmt_new")
      expect(comment.status).to eq("pending")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts/#{post_id}/comments?profile_id=#{profile_id}")
        .with { |req| JSON.parse(req.body)["text"] == "Nice!" }
    end

    it "creates a reply with parent_id" do
      reply = mock_comment.merge(id: "cmt_reply", body: "Thanks!", status: "pending", replies: [])
      stub_api(:post, "/posts/#{post_id}/comments",
        body: reply,
        query: { profile_id: profile_id })

      comment = client.comments.create(post_id, "Thanks!", profile_id: profile_id, parent_id: "cmt_abc123")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts/#{post_id}/comments?profile_id=#{profile_id}")
        .with { |req|
          body = JSON.parse(req.body)
          body["text"] == "Thanks!" && body["parent_id"] == "cmt_abc123"
        }
    end
  end

  describe "#delete" do
    it "deletes a comment" do
      stub_api(:delete, "/posts/#{post_id}/comments/#{comment_id}",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.delete(post_id, comment_id, profile_id: profile_id)
      expect(result).to be_a(PostProxy::AcceptedResponse)
      expect(result.accepted).to be true
    end
  end

  describe "#hide" do
    it "hides a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/hide",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.hide(post_id, comment_id, profile_id: profile_id)
      expect(result).to be_a(PostProxy::AcceptedResponse)
      expect(result.accepted).to be true
    end
  end

  describe "#unhide" do
    it "unhides a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/unhide",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.unhide(post_id, comment_id, profile_id: profile_id)
      expect(result.accepted).to be true
    end
  end

  describe "#like" do
    it "likes a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/like",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.like(post_id, comment_id, profile_id: profile_id)
      expect(result.accepted).to be true
    end
  end

  describe "#unlike" do
    it "unlikes a comment" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/unlike",
        body: { accepted: true },
        query: { profile_id: profile_id })

      result = client.comments.unlike(post_id, comment_id, profile_id: profile_id)
      expect(result.accepted).to be true
    end
  end

  describe "attachments and metadata" do
    it "parses attachments into Attachment models and exposes metadata" do
      comment = mock_comment.merge(
        metadata: { follower_count: 482, is_verified: true },
        attachments: [
          { id: "att_1", type: "image", url: "https://cdn.example.com/a.jpg", status: "processed", external_id: nil }
        ]
      )
      stub_api(:get, "/posts/#{post_id}/comments/#{comment_id}",
        body: comment,
        query: { profile_id: profile_id })

      result = client.comments.get(post_id, comment_id, profile_id: profile_id)
      expect(result.metadata[:follower_count]).to eq(482)
      expect(result.attachments.length).to eq(1)
      expect(result.attachments.first).to be_a(PostProxy::Attachment)
      expect(result.attachments.first.type).to eq("image")
      expect(result.attachments.first.status).to eq("processed")
    end

    it "defaults attachments to an empty array" do
      result = PostProxy::Comment.new(id: "c1", body: "hi", status: "synced", created_at: "2026-03-25T10:00:00Z")
      expect(result.attachments).to eq([])
      expect(result.metadata).to be_nil
    end
  end

  describe "#private_reply" do
    let(:mock_message) do
      {
        id: "msg_222",
        chat_id: "chat_xyz789",
        external_id: nil,
        direction: "outbound",
        body: "DM-ing you the details.",
        status: "pending",
        external_comment_id: "17858893269123456",
        reactions: [],
        attachments: [],
        is_unsupported: false,
        created_at: "2026-05-31T15:30:05.000Z",
      }
    end

    it "sends a private reply and returns a Message" do
      stub_api(:post, "/posts/#{post_id}/comments/#{comment_id}/private_reply",
        body: mock_message,
        query: { profile_id: profile_id })

      msg = client.comments.private_reply(post_id, comment_id, profile_id: profile_id, text: "DM-ing you the details.")
      expect(msg).to be_a(PostProxy::Message)
      expect(msg.id).to eq("msg_222")
      expect(msg.external_comment_id).to eq("17858893269123456")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/posts/#{post_id}/comments/#{comment_id}/private_reply?profile_id=#{profile_id}")
        .with { |req| JSON.parse(req.body)["text"] == "DM-ing you the details." }
    end
  end

  describe "date filters" do
    it "passes from and to on the per-post list" do
      stub = stub_api(:get, "/posts/#{post_id}/comments",
        body: { data: [mock_comment], total: 1, page: 0, per_page: 20 },
        query: { profile_id: profile_id, from: "2026-03-25", to: "2026-03-26T12:00:00Z" })

      client.comments.list(post_id, profile_id: profile_id, from: "2026-03-25", to: "2026-03-26T12:00:00Z")
      expect(stub).to have_been_requested
    end
  end

  describe "#list_all" do
    let(:bulk_comment) do
      {
        post_id: "abc123xyz",
        profile_id: "prof456",
        platform: "instagram",
        id: "cmt_abc123",
        external_id: "17858893269123456",
        body: "Great post!",
        status: "synced",
        author_username: "someuser",
        author_avatar_url: nil,
        author_external_id: "12345",
        metadata: nil,
        parent_external_id: nil,
        like_count: 3,
        is_hidden: false,
        permalink: nil,
        platform_data: nil,
        attachments: [],
        posted_at: "2026-03-25T10:00:00Z",
        created_at: "2026-03-25T10:01:00Z",
      }
    end

    let(:bulk_reply) do
      bulk_comment.merge(
        id: "cmt_def456",
        body: "Thanks!",
        parent_external_id: "17858893269123456",
        like_count: 1
      )
    end

    it "lists comments across posts" do
      stub = stub_api(:get, "/comments",
        body: { total: 2, page: 0, per_page: 50, data: [bulk_comment, bulk_reply] },
        query: {
          profiles: "instagram,prof456",
          post_ids: "abc123xyz,def456uvw",
          from: "2026-03-25",
          per_page: "50"
        })

      result = client.comments.list_all(
        profiles: ["instagram", "prof456"],
        post_ids: ["abc123xyz", "def456uvw"],
        from: "2026-03-25",
        per_page: 50
      )

      expect(result).to be_a(PostProxy::PaginatedResponse)
      expect(result.total).to eq(2)
      expect(result.data.first).to be_a(PostProxy::BulkComment)
      expect(result.data.first.post_id).to eq("abc123xyz")
      expect(result.data.first.profile_id).to eq("prof456")
      expect(result.data.first.platform).to eq("instagram")
      # Flat: the reply is its own entry, linked by parent_external_id.
      expect(result.data.last.parent_external_id).to eq("17858893269123456")
      expect(stub).to have_been_requested
    end

    it "sends no filters when none are given" do
      stub = stub_api(:get, "/comments", body: { total: 0, page: 0, per_page: 20, data: [] })

      client.comments.list_all
      expect(stub).to have_been_requested
    end
  end

  describe "idempotency" do
    it "sends the key when creating a comment" do
      stub = stub_request(:post, "#{BASE_URL}/api/posts/#{post_id}/comments")
        .with(query: { profile_id: profile_id }, headers: { "Idempotency-Key" => "key-42" })
        .to_return(status: 200, body: mock_comment.to_json,
                   headers: { "Content-Type" => "application/json" })

      client.comments.create(post_id, "Nice", profile_id: profile_id, idempotency_key: "key-42")
      expect(stub).to have_been_requested
    end
  end
end
