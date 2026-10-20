require "spec_helper"

RSpec.describe PostProxy::Resources::Placements do
  let(:client) { new_client }

  let(:mock_placement) do
    {
      id: "pl_1",
      platform: "facebook",
      external_id: "1234567890",
      name: "Acme Page",
      avatar_url: nil,
      status: "active",
      active_profile: { id: "prof_1", name: "Jane", connected: true },
      linked_profiles: [{ id: "prof_2", name: "John", connected: true }]
    }
  end

  describe "#list" do
    it "returns paginated account placements" do
      stub = stub_api(:get, "/placements",
        body: { total: 1, page: 2, per_page: 10, data: [mock_placement] },
        query: { page: "2", per_page: "10" })

      result = client.placements.list(page: 2, per_page: 10)
      expect(stub).to have_been_requested
      expect(result).to be_a(PostProxy::PaginatedResponse)
      placement = result.data.first
      expect(placement).to be_a(PostProxy::AccountPlacement)
      expect(placement.active_profile).to be_a(PostProxy::AccountPlacementProfile)
      expect(placement.active_profile.id).to eq("prof_1")
      expect(placement.linked_profiles.first.name).to eq("John")
    end
  end

  describe "#set_active_profile" do
    it "patches the active profile" do
      stub = stub_request(:patch, "#{BASE_URL}/api/placements/pl_1/set_active_profile")
        .with(body: { profile_id: "prof_2" })
        .to_return(status: 200, body: mock_placement.to_json, headers: { "Content-Type" => "application/json" })

      placement = client.placements.set_active_profile("pl_1", "prof_2")
      expect(stub).to have_been_requested
      expect(placement.name).to eq("Acme Page")
    end
  end
end

RSpec.describe PostProxy::Resources::ApiKeys do
  let(:client) { new_client }

  it "lists api keys" do
    stub_api(:get, "/api_keys", body: {
      data: [{ id: "k1", name: "CI", profile_group_id: "pg_1", sandbox: false, created_at: "2026-09-09T00:00:00Z" }]
    })

    result = client.api_keys.list
    expect(result).to be_a(PostProxy::ListResponse)
    key = result.data.first
    expect(key).to be_a(PostProxy::ApiKey)
    expect(key.name).to eq("CI")
    expect(key.token).to be_nil
    expect(key.created_at).to be_a(Time)
  end

  it "creates an api key" do
    stub = stub_request(:post, "#{BASE_URL}/api/api_keys")
      .with(body: { name: "CI", profile_group_id: "pg_1" }, headers: { "Idempotency-Key" => "idem" })
      .to_return(status: 201, headers: { "Content-Type" => "application/json" }, body: {
        id: "k1", name: "CI", profile_group_id: "pg_1", sandbox: false, token: "secret",
        created_at: "2026-09-09T00:00:00Z"
      }.to_json)

    key = client.api_keys.create("CI", profile_group_id: "pg_1", idempotency_key: "idem")
    expect(stub).to have_been_requested
    expect(key.token).to eq("secret")
  end

  it "deletes an api key" do
    stub_api(:delete, "/api_keys/k1", body: { deleted: true })

    result = client.api_keys.delete("k1")
    expect(result).to be_a(PostProxy::DeleteResponse)
    expect(result.deleted).to be true
  end
end
