require "spec_helper"
require "tempfile"

RSpec.describe PostProxy::Resources::Messages do
  let(:client) { new_client }
  let(:chat_id) { "chat_xyz789" }

  let(:mock_inbound) do
    {
      id: "msg_111",
      chat_id: "chat_xyz789",
      external_id: "mid.abc123",
      direction: "inbound",
      body: "Hey, do you ship internationally?",
      status: "received",
      tag: nil,
      error_message: nil,
      platform_data: nil,
      external_posted_at: "2026-05-31T14:02:00.000Z",
      external_delivered_at: nil,
      external_read_at: nil,
      external_edited_at: nil,
      reactions: [
        { sender_external_id: "psid_123", emoji: "❤️", reaction: "love", at: "2026-05-31T14:04:00.000Z" }
      ],
      attachments: [
        { id: "att_1", type: "image", url: "https://cdn.example.com/a.jpg", status: "processed", external_id: nil }
      ],
      is_unsupported: false,
      created_at: "2026-05-31T14:02:01.000Z",
    }
  end

  let(:mock_outbound) do
    {
      id: "msg_222",
      chat_id: "chat_xyz789",
      external_id: nil,
      direction: "outbound",
      body: "Yes, we ship worldwide!",
      status: "pending",
      tag: nil,
      error_message: nil,
      platform_data: nil,
      external_posted_at: nil,
      attachments: [],
      reactions: [],
      is_unsupported: false,
      created_at: "2026-05-31T15:30:05.000Z",
    }
  end

  describe "#list" do
    it "returns paginated messages and parses nested reactions/attachments" do
      stub_api(:get, "/chats/#{chat_id}/messages",
        body: { data: [mock_inbound], total: 1, page: 0, per_page: 20 },
        query: { direction: "inbound" })

      result = client.messages.list(chat_id, direction: "inbound")
      expect(result).to be_a(PostProxy::PaginatedResponse)
      msg = result.data.first
      expect(msg).to be_a(PostProxy::Message)
      expect(msg.direction).to eq("inbound")
      expect(msg.reactions.first).to be_a(PostProxy::Reaction)
      expect(msg.reactions.first.reaction).to eq("love")
      expect(msg.reactions.first.at).to be_a(Time)
      expect(msg.attachments.first).to be_a(PostProxy::Attachment)
      expect(msg.attachments.first.type).to eq("image")
    end
  end

  describe "#send" do
    it "sends a text message as JSON" do
      stub_api(:post, "/chats/#{chat_id}/messages", body: mock_outbound)

      msg = client.messages.send(chat_id, body: "Yes, we ship worldwide!")
      expect(msg).to be_a(PostProxy::Message)
      expect(msg.id).to eq("msg_222")
      expect(msg.status).to eq("pending")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/chats/#{chat_id}/messages")
        .with { |req| JSON.parse(req.body)["body"] == "Yes, we ship worldwide!" }
    end

    it "includes tag and reply_markup in the body" do
      stub_api(:post, "/chats/#{chat_id}/messages", body: mock_outbound)

      client.messages.send(chat_id, body: "Pick one:", tag: "HUMAN_AGENT",
        reply_markup: { inline_keyboard: [[{ text: "Track", callback_data: "t:1" }]] })

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/chats/#{chat_id}/messages")
        .with { |req|
          body = JSON.parse(req.body)
          body["tag"] == "HUMAN_AGENT" && !body["reply_markup"].nil?
        }
    end

    it "sends quick replies, accepting models and hashes" do
      stub_api(:post, "/chats/#{chat_id}/messages",
        body: mock_outbound.merge(
          quick_replies: [{ content_type: "text", title: "Track order", payload: "TRACK" }]
        ))

      msg = client.messages.send(chat_id, body: "What can I help with?",
        quick_replies: [
          PostProxy::QuickReply.new(title: "Track order", payload: "TRACK"),
          { title: "Talk to support", payload: "HELP" }
        ])

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/chats/#{chat_id}/messages")
        .with { |req|
          JSON.parse(req.body)["quick_replies"] == [
            { "title" => "Track order", "payload" => "TRACK" },
            { "title" => "Talk to support", "payload" => "HELP" }
          ]
        }

      expect(msg.quick_replies.first).to be_a(PostProxy::QuickReply)
      expect(msg.quick_replies.first.content_type).to eq("text")
    end

    it "sends buttons with a card" do
      stub_api(:post, "/chats/#{chat_id}/messages",
        body: mock_outbound.merge(
          buttons: [{ type: "web_url", title: "Track", url: "https://shop.example.com" }],
          card: { subtitle: "Arriving Friday" }
        ))

      msg = client.messages.send(chat_id, body: "Your order shipped",
        buttons: [
          PostProxy::MessageButton.new(type: "web_url", title: "Track", url: "https://shop.example.com"),
          { type: "postback", title: "Cancel", payload: "CANCEL:123" }
        ],
        card: PostProxy::MessageCard.new(
          subtitle: "Arriving Friday",
          default_action: { type: "web_url", url: "https://shop.example.com" }
        ))

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/chats/#{chat_id}/messages")
        .with { |req|
          body = JSON.parse(req.body)
          body["buttons"] == [
            { "type" => "web_url", "title" => "Track", "url" => "https://shop.example.com" },
            { "type" => "postback", "title" => "Cancel", "payload" => "CANCEL:123" }
          ] &&
            body["card"] == {
              "subtitle" => "Arriving Friday",
              "default_action" => { "type" => "web_url", "url" => "https://shop.example.com" }
            }
        }

      expect(msg.buttons.first).to be_a(PostProxy::MessageButton)
      expect(msg.buttons.first.url).to eq("https://shop.example.com")
      expect(msg.card).to be_a(PostProxy::MessageCard)
      expect(msg.card.subtitle).to eq("Arriving Friday")
    end

    it "sends media URLs as JSON" do
      stub_api(:post, "/chats/#{chat_id}/messages", body: mock_outbound)

      client.messages.send(chat_id, media: ["https://cdn.example.com/photo.png"])

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/chats/#{chat_id}/messages")
        .with { |req| JSON.parse(req.body)["media"] == ["https://cdn.example.com/photo.png"] }
    end

    it "uploads local files as multipart" do
      stub_request(:post, "#{BASE_URL}/api/chats/#{chat_id}/messages")
        .to_return(status: 202, body: mock_outbound.to_json,
          headers: { "Content-Type" => "application/json" })

      file = Tempfile.new(["photo", ".png"])
      file.write("fake")
      file.rewind
      begin
        msg = client.messages.send(chat_id, body: "Here you go", media_files: [file.path])
        expect(msg).to be_a(PostProxy::Message)
      ensure
        file.close
        file.unlink
      end

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/chats/#{chat_id}/messages")
        .with { |req| req.headers["Content-Type"].to_s.include?("multipart/form-data") }
    end
  end

  describe "#get" do
    it "returns a single message" do
      stub_api(:get, "/messages/msg_111", body: mock_inbound)

      msg = client.messages.get("msg_111")
      expect(msg.id).to eq("msg_111")
    end

    it "parses tapped_action on an inbound tap" do
      stub_api(:get, "/messages/msg_333",
        body: mock_inbound.merge(
          id: "msg_333",
          body: "Track order",
          tapped_action: { kind: "quick_reply", payload: "TRACK", title: "Track order" }
        ))

      msg = client.messages.get("msg_333")
      expect(msg.tapped_action).to be_a(PostProxy::TappedAction)
      expect(msg.tapped_action.kind).to eq("quick_reply")
      expect(msg.tapped_action.payload).to eq("TRACK")
      expect(msg.tapped_action.title).to eq("Track order")
    end

    it "leaves interactive fields nil when the API omits them" do
      stub_api(:get, "/messages/msg_111", body: mock_inbound)

      msg = client.messages.get("msg_111")
      expect(msg.quick_replies).to be_nil
      expect(msg.buttons).to be_nil
      expect(msg.card).to be_nil
      expect(msg.tapped_action).to be_nil
    end
  end

  describe "#edit" do
    it "edits a message body" do
      stub_api(:patch, "/messages/msg_222", body: mock_outbound.merge(body: "Updated"))

      msg = client.messages.edit("msg_222", body: "Updated")
      expect(msg.body).to eq("Updated")

      expect(WebMock).to have_requested(:patch, "#{BASE_URL}/api/messages/msg_222")
        .with { |req| JSON.parse(req.body)["body"] == "Updated" }
    end
  end

  describe "#react" do
    it "reacts to a message" do
      stub_api(:post, "/messages/msg_111/react", body: mock_inbound)

      msg = client.messages.react("msg_111", reaction: "love", emoji: "❤️")
      expect(msg.id).to eq("msg_111")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/messages/msg_111/react")
        .with { |req| JSON.parse(req.body)["reaction"] == "love" }
    end
  end

  describe "#unreact" do
    it "removes a reaction" do
      stub_api(:delete, "/messages/msg_111/unreact", body: mock_inbound)

      msg = client.messages.unreact("msg_111")
      expect(msg.id).to eq("msg_111")
    end
  end
end

RSpec.describe PostProxy::Resources::Messages, "carousels and WhatsApp payloads" do
  let(:client) { new_client }
  let(:url) { "#{BASE_URL}/api/chats/chat_1/messages" }

  def stub_send(body)
    stub_request(:post, url).with(body: body)
      .to_return(status: 202, body: { id: "msg_1" }.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "sends a carousel" do
    stub = stub_send(elements: [
      { title: "Red", image_url: "https://img.test/r.jpg" },
      { title: "Blue", subtitle: "Restocked", buttons: [{ type: "postback", title: "Pick", payload: "BLUE" }] }
    ])

    client.messages.send("chat_1", elements: [
      PostProxy::MessageElement.new(title: "Red", image_url: "https://img.test/r.jpg"),
      { title: "Blue", subtitle: "Restocked", buttons: [{ type: "postback", title: "Pick", payload: "BLUE" }] }
    ])
    expect(stub).to have_been_requested
  end

  it "sends a WhatsApp template" do
    template = {
      name: "order_update",
      language: "en_US",
      variables: ["#1234"],
      button_params: [{ index: 0, sub_type: "url", text: "1234" }]
    }
    stub = stub_send(template: template)

    client.messages.send("chat_1", template: PostProxy::MessageTemplateInput.new(**template))
    expect(stub).to have_been_requested
  end

  it "sends WhatsApp location, contacts and send options" do
    stubs = [
      stub_send(location: { latitude: 52.5, longitude: 13.4, name: "Store" }),
      stub_send(contacts: [{ name: { formatted_name: "Jane" } }]),
      stub_send(body: "Your code is 1234", category: "utility", link_preview: false),
      stub_send(media: ["https://files.test/a.pdf"], filename: "invoice.pdf"),
      stub_send(media: ["https://files.test/a.ogg"], voice_note: true),
      stub_send(interactive: { type: "button", body: { text: "Pick" } })
    ]

    client.messages.send("chat_1",
      location: PostProxy::MessageLocation.new(latitude: 52.5, longitude: 13.4, name: "Store"))
    client.messages.send("chat_1", contacts: [{ name: { formatted_name: "Jane" } }])
    client.messages.send("chat_1", body: "Your code is 1234", category: "utility", link_preview: false)
    client.messages.send("chat_1", media: ["https://files.test/a.pdf"], filename: "invoice.pdf")
    client.messages.send("chat_1", media: ["https://files.test/a.ogg"], voice_note: true)
    client.messages.send("chat_1", interactive: { type: "button", body: { text: "Pick" } })

    stubs.each { |s| expect(s).to have_been_requested }
  end

  it "parses the new message fields" do
    msg = PostProxy::Message.new(
      id: "msg_1", chat_id: "chat_1", direction: "outbound", status: "failed",
      elements: [{ title: "Red", buttons: [{ type: "postback", title: "Pick", payload: "RED" }] }],
      story_reply: { story_id: "s1" },
      location: { latitude: 1.5, longitude: 2.5 },
      contacts: [{ name: { formatted_name: "Jane" } }],
      interactive: { type: "button" },
      template: { id: "tpl_1", external_id: nil, name: "order_update", language: "en_US", variables: ["x"] },
      error_details: { platform_error_code: 131_047, platform_error_message: "Re-engagement" }
    )

    expect(msg.elements.first).to be_a(PostProxy::MessageElement)
    expect(msg.elements.first.buttons.first).to be_a(PostProxy::MessageButton)
    expect(msg.location).to be_a(PostProxy::MessageLocation)
    expect(msg.location.latitude).to eq(1.5)
    expect(msg.template).to be_a(PostProxy::MessageTemplateRef)
    expect(msg.template.name).to eq("order_update")
    expect(msg.error_details).to be_a(PostProxy::ErrorDetails)
    expect(msg.story_reply[:story_id]).to eq("s1")
    expect(msg.contacts.first[:name][:formatted_name]).to eq("Jane")
  end

  it "leaves the new fields nil when absent" do
    msg = PostProxy::Message.new(id: "msg_1", chat_id: "chat_1", direction: "inbound", status: "received")
    expect(msg.elements).to be_nil
    expect(msg.template).to be_nil
    expect(msg.location).to be_nil
  end
end
