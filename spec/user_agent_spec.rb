require "spec_helper"

RSpec.describe "User-Agent header" do
  let(:client) { new_client }

  it "sends User-Agent on requests" do
    stub_api(:get, "/profiles", body: { data: [] })
    client.profiles.list
    expect(WebMock).to have_requested(:get, "#{BASE_URL}/api/profiles")
      .with { |req|
        ua = req.headers["User-Agent"]
        ua.start_with?("postproxy-ruby/#{PostProxy::VERSION}") && ua.include?("ruby/")
      }
  end

  it "has bumped VERSION constant" do
    expect(PostProxy::VERSION).to eq("1.12.0")
  end
end
