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

  describe "#delete" do
    it "deletes a profile" do
      stub_api(:delete, "/profiles/prof-1", body: { success: true })

      result = client.profiles.delete("prof-1")
      expect(result).to be_a(PostProxy::SuccessResponse)
      expect(result.success).to be true
    end
  end
end
