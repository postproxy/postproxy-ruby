require "spec_helper"

RSpec.describe PostProxy::Resources::WhatsAppTemplates do
  let(:client) { new_client }
  let(:base) { "#{BASE_URL}/api/profiles/prof_wa/templates" }

  let(:mock_template) do
    {
      id: "tpl_1",
      external_id: "998877",
      profile_id: "prof_wa",
      name: "order_update",
      language: "en_US",
      category: "UTILITY",
      status: "APPROVED",
      parameter_format: "POSITIONAL",
      components: [{ type: "BODY", text: "Order {{1}} shipped" }],
      variable_count: 1,
      created_at: "2026-09-28T00:00:00Z",
      updated_at: "2026-09-28T00:00:00Z"
    }
  end

  def json_response(body)
    { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  it "lists templates with filters" do
    stub = stub_api(:get, "/profiles/prof_wa/templates",
      body: { data: [mock_template] }, query: { status: "APPROVED", refresh: "true" })

    result = client.whatsapp_templates.list("prof_wa", status: "APPROVED", refresh: true)
    expect(stub).to have_been_requested
    template = result.data.first
    expect(template).to be_a(PostProxy::WhatsAppTemplate)
    expect(template.name).to eq("order_update")
    expect(template.components.first[:type]).to eq("BODY")
    expect(template.created_at).to be_a(Time)
  end

  it "gets a template by name and language, URL-encoding the id" do
    stub = stub_request(:get, "#{base}/order%20update")
      .with(query: { language: "en_US" })
      .to_return(json_response(mock_template))

    client.whatsapp_templates.get("prof_wa", "order update", language: "en_US")
    expect(stub).to have_been_requested
  end

  it "creates, updates and deletes a template" do
    create = stub_request(:post, base)
      .with(body: {
        name: "order_update", category: "UTILITY", language: "en_US",
        components: [{ type: "BODY", text: "Order {{1}} shipped" }]
      })
      .to_return(json_response(mock_template))
    update = stub_request(:patch, "#{base}/tpl_1")
      .with(body: { message_send_ttl_seconds: 3600 })
      .to_return(json_response(mock_template))
    delete = stub_request(:delete, "#{base}/order_update")
      .with { |req| req.uri.query.nil? }
      .to_return(json_response({ success: true }))

    client.whatsapp_templates.create("prof_wa",
      name: "order_update", category: "UTILITY", language: "en_US",
      components: [{ type: "BODY", text: "Order {{1}} shipped" }])
    client.whatsapp_templates.update("prof_wa", "tpl_1", message_send_ttl_seconds: 3600)
    result = client.whatsapp_templates.delete("prof_wa", "order_update")

    [create, update, delete].each { |s| expect(s).to have_been_requested }
    expect(result[:success]).to be true
  end

  it "reads the template library" do
    stub = stub_request(:get, "#{base}/library")
      .with(query: { name: "delivery" })
      .to_return(json_response({ data: [] }))

    client.whatsapp_templates.library("prof_wa", name: "delivery")
    expect(stub).to have_been_requested
  end
end

RSpec.describe PostProxy::Resources::WhatsApp do
  let(:client) { new_client }
  let(:wa) { client.whatsapp }
  let(:base) { "#{BASE_URL}/api/profiles/prof_wa/whatsapp" }

  def stub_wa(method, action, query: nil, json: nil, body: { success: true })
    stub = stub_request(method, "#{base}/#{action}")
    stub = stub.with(query: query) if query
    stub = stub.with(body: json) if json
    stub.to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "passes phone_number_id as a query param on reads" do
    info = stub_wa(:get, "number_info", query: { phone_number_id: "pn_1" }, body: { verified_name: "Acme" })
    blocked = stub_wa(:get, "blocked_users", query: { phone_number_id: "pn_1", limit: "10" })

    result = wa.number_info("prof_wa", "pn_1")
    wa.blocked_users("prof_wa", "pn_1", limit: 10)

    expect(result[:verified_name]).to eq("Acme")
    [info, blocked].each { |s| expect(s).to have_been_requested }
  end

  it "sends writes as JSON bodies" do
    stubs = [
      stub_wa(:post, "register_phone_number", json: { phone_number_id: "pn_1", pin: "123456" }),
      stub_wa(:post, "request_verification_code", json: { phone_number_id: "pn_1", method: "SMS", language: "en" }),
      stub_wa(:post, "verify_phone_number", json: { phone_number_id: "pn_1", code: "000111" }),
      stub_wa(:patch, "update_business_profile",
        json: { phone_number_id: "pn_1", about: "Hi", websites: ["https://acme.test"] }),
      stub_wa(:post, "update_business_profile_photo", json: { phone_number_id: "pn_1", url: "https://img.test/a.png" }),
      stub_wa(:post, "request_display_name_change", json: { phone_number_id: "pn_1", display_name: "Acme Co" }),
      stub_wa(:put, "set_username",
        json: { phone_number_id: "pn_1", username: "acme", transfer_action: "force_transfer" }),
      stub_wa(:post, "block_users", json: { phone_number_id: "pn_1", users: ["15551234567"] })
    ]

    wa.register_phone_number("prof_wa", "pn_1", "123456")
    wa.request_verification_code("prof_wa", "pn_1", method: "SMS", language: "en")
    wa.verify_phone_number("prof_wa", "pn_1", "000111")
    wa.update_business_profile("prof_wa", "pn_1", about: "Hi", websites: ["https://acme.test"])
    wa.update_business_profile_photo("prof_wa", "pn_1", url: "https://img.test/a.png")
    wa.request_display_name_change("prof_wa", "pn_1", "Acme Co")
    wa.set_username("prof_wa", "pn_1", "acme", transfer_action: "force_transfer")
    wa.block_users("prof_wa", "pn_1", ["15551234567"])

    stubs.each { |s| expect(s).to have_been_requested }
  end

  it "deletes the username via query params" do
    stub = stub_request(:delete, "#{base}/delete_username")
      .with(query: { phone_number_id: "pn_1" }) { |req| req.body.to_s.empty? }
      .to_return(status: 200, body: { success: true }.to_json, headers: { "Content-Type" => "application/json" })

    wa.delete_username("prof_wa", "pn_1")
    expect(stub).to have_been_requested
  end

  it "manages groups" do
    stubs = [
      stub_wa(:post, "create_group",
        json: { phone_number_id: "pn_1", subject: "Customers", join_approval_mode: "approval_required" }),
      stub_wa(:get, "group", query: { phone_number_id: "pn_1", group_id: "g_1" }),
      stub_wa(:patch, "update_group", json: { phone_number_id: "pn_1", group_id: "g_1", subject: "VIPs" }),
      stub_wa(:post, "add_group_participants",
        json: { phone_number_id: "pn_1", group_id: "g_1", phone_numbers: ["15551234567"] }),
      stub_wa(:post, "create_group_invite_link", json: { phone_number_id: "pn_1", group_id: "g_1" }),
      stub_wa(:post, "approve_group_join_requests",
        json: { phone_number_id: "pn_1", group_id: "g_1", phone_numbers: ["15557654321"] }),
      stub_wa(:delete, "delete_group", query: { phone_number_id: "pn_1", group_id: "g_1" })
    ]

    wa.create_group("prof_wa", "pn_1", "Customers", join_approval_mode: "approval_required")
    wa.group("prof_wa", "pn_1", "g_1")
    wa.update_group("prof_wa", "pn_1", "g_1", subject: "VIPs")
    wa.add_group_participants("prof_wa", "pn_1", "g_1", ["15551234567"])
    wa.create_group_invite_link("prof_wa", "pn_1", "g_1")
    wa.approve_group_join_requests("prof_wa", "pn_1", "g_1", ["15557654321"])
    wa.delete_group("prof_wa", "pn_1", "g_1")

    stubs.each { |s| expect(s).to have_been_requested }
  end

  it "sends conversion events without a phone number id" do
    dataset = stub_request(:get, "#{base}/dataset")
      .with { |req| req.uri.query.nil? }
      .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })
    event = stub_wa(:post, "send_conversion_event", json: {
      event_name: "Purchase", event_id: "order-42", chat_id: "chat_1", currency: "USD", value: 19.99
    }, body: { events_received: 1 })

    wa.dataset("prof_wa")
    wa.send_conversion_event("prof_wa",
      event_name: "Purchase", event_id: "order-42", chat_id: "chat_1", currency: "USD", value: 19.99)

    [dataset, event].each { |s| expect(s).to have_been_requested }
  end

  it "returns raw bytes for media" do
    stub_request(:get, "#{base}/media")
      .with(query: { phone_number_id: "pn-1", media_id: "media-1" })
      .to_return(status: 200, body: [1, 2, 3].pack("C*"), headers: { "Content-Type" => "image/jpeg" })

    result = wa.media("prof_wa", "pn-1", "media-1")
    expect(result).to be_a(PostProxy::RawResponse)
    expect(result.content_type).to eq("image/jpeg")
    expect(result.data.bytes).to eq([1, 2, 3])
  end

  it "raises on a failed media download" do
    stub_request(:get, "#{base}/media")
      .with(query: { phone_number_id: "pn-1", media_id: "gone" })
      .to_return(status: 404, body: { error: "Not found" }.to_json)

    expect { wa.media("prof_wa", "pn-1", "gone") }.to raise_error(PostProxy::NotFoundError)
  end
end
