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
end
