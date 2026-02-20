require "spec_helper"

RSpec.describe PostProxy::Client do
  describe "authentication" do
    it "sends Bearer token in Authorization header" do
      stub = stub_api(:get, "/profiles", body: { data: [] })

      client = new_client
      client.profiles.list

      expect(stub).to have_been_requested
      expect(WebMock).to have_requested(:get, "#{BASE_URL}/api/profiles")
        .with(headers: { "Authorization" => "Bearer test-key" })
    end
  end

  describe "profile_group_id" do
    it "sends default profile_group_id as query param" do
      stub = stub_api(:get, "/profiles",
        body: { data: [] },
        query: { profile_group_id: "pg-123" }
      )

      client = new_client(profile_group_id: "pg-123")
      client.profiles.list

      expect(stub).to have_been_requested
    end

    it "allows overriding profile_group_id per request" do
      stub = stub_api(:get, "/profiles",
        body: { data: [] },
        query: { profile_group_id: "pg-override" }
      )

      client = new_client(profile_group_id: "pg-123")
      client.profiles.list(profile_group_id: "pg-override")

      expect(stub).to have_been_requested
    end
  end

  describe "error handling" do
    it "raises AuthenticationError on 401" do
      stub_api(:get, "/profiles", status: 401, body: { error: "Unauthorized" })
      client = new_client

      expect { client.profiles.list }.to raise_error(PostProxy::AuthenticationError) do |e|
        expect(e.status_code).to eq(401)
      end
    end

    it "raises NotFoundError on 404" do
      stub_api(:get, "/profiles/bad-id", status: 404, body: { error: "Not found" })
      client = new_client

      expect { client.profiles.get("bad-id") }.to raise_error(PostProxy::NotFoundError) do |e|
        expect(e.status_code).to eq(404)
      end
    end

    it "raises ValidationError on 422" do
      stub_api(:get, "/profiles", status: 422, body: { error: "Invalid" })
      client = new_client

      expect { client.profiles.list }.to raise_error(PostProxy::ValidationError) do |e|
        expect(e.status_code).to eq(422)
      end
    end

    it "raises BadRequestError on 400" do
      stub_api(:get, "/profiles", status: 400, body: { error: "Bad request" })
      client = new_client

      expect { client.profiles.list }.to raise_error(PostProxy::BadRequestError) do |e|
        expect(e.status_code).to eq(400)
      end
    end

    it "raises Error on other status codes" do
      stub_api(:get, "/profiles", status: 500, body: { error: "Server error" })
      client = new_client

      expect { client.profiles.list }.to raise_error(PostProxy::Error) do |e|
        expect(e.status_code).to eq(500)
      end
    end
  end
end
