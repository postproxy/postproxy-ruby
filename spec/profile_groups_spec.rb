require "spec_helper"

RSpec.describe PostProxy::Resources::ProfileGroups do
  let(:client) { new_client }

  describe "#list" do
    it "returns profile groups" do
      stub_api(:get, "/profile_groups", body: {
        data: [
          { id: "pg-1", name: "My Group", profiles_count: 3 }
        ]
      })

      result = client.profile_groups.list
      expect(result).to be_a(PostProxy::ListResponse)
      expect(result.data.length).to eq(1)
      expect(result.data.first.id).to eq("pg-1")
      expect(result.data.first.name).to eq("My Group")
      expect(result.data.first.profiles_count).to eq(3)
    end
  end

  describe "#get" do
    it "returns a single profile group" do
      stub_api(:get, "/profile_groups/pg-1", body: {
        id: "pg-1", name: "My Group", profiles_count: 5
      })

      group = client.profile_groups.get("pg-1")
      expect(group.id).to eq("pg-1")
      expect(group.profiles_count).to eq(5)
    end
  end

  describe "#create" do
    it "creates a profile group" do
      stub_api(:post, "/profile_groups", body: {
        id: "pg-new", name: "New Group", profiles_count: 0
      })

      group = client.profile_groups.create("New Group")
      expect(group.id).to eq("pg-new")
      expect(group.name).to eq("New Group")

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/profile_groups")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:name] == "New Group"
        }
    end
  end

  describe "#delete" do
    it "deletes a profile group" do
      stub_api(:delete, "/profile_groups/pg-1", body: { deleted: true })

      result = client.profile_groups.delete("pg-1")
      expect(result).to be_a(PostProxy::DeleteResponse)
      expect(result.deleted).to be true
    end
  end

  describe "#initialize_connection" do
    it "returns a connection URL" do
      stub_api(:post, "/profile_groups/pg-1/initialize_connection", body: {
        url: "https://oauth.example.com/connect",
        success: true
      })

      result = client.profile_groups.initialize_connection("pg-1",
        platform: "instagram",
        redirect_url: "https://myapp.com/callback"
      )

      expect(result).to be_a(PostProxy::ConnectionResponse)
      expect(result.url).to eq("https://oauth.example.com/connect")
      expect(result.success).to be true

      expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/profile_groups/pg-1/initialize_connection")
        .with { |req|
          body = JSON.parse(req.body, symbolize_names: true)
          body[:platform] == "instagram" && body[:redirect_url] == "https://myapp.com/callback"
        }
    end
  end
end
