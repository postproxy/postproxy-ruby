require "spec_helper"

RSpec.describe "Telegram + BlueSky connect" do
  let(:client) { new_client }

  it "connect_bluesky posts identifier + app_password" do
    stub_api(:post, "/profile_groups/pg-1/initialize_connection", body: {
      success: true,
      profile: {
        id: "pf_bsky_1", network: "bluesky", name: "Jane",
        external_username: "jane.bsky.social"
      }
    })

    result = client.profile_groups.connect_bluesky("pg-1",
      identifier: "jane.bsky.social",
      app_password: "xxxx"
    )

    expect(result).to be_a(PostProxy::BlueskyConnectionResponse)
    expect(result.success).to be true
    expect(result.profile).to be_a(PostProxy::SyncProfile)
    expect(result.profile.id).to eq("pf_bsky_1")

    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/profile_groups/pg-1/initialize_connection")
      .with { |req|
        body = JSON.parse(req.body, symbolize_names: true)
        body == { platform: "bluesky", identifier: "jane.bsky.social", app_password: "xxxx" }
      }
  end

  it "connect_telegram posts bot_token" do
    stub_api(:post, "/profile_groups/pg-1/initialize_connection", body: {
      success: true,
      profile: {
        id: "pf_tg_1", network: "telegram", name: "My Bot",
        external_username: "my_bot"
      },
      next_step: "Add bot as admin"
    })

    result = client.profile_groups.connect_telegram("pg-1", bot_token: "123:ABC")

    expect(result).to be_a(PostProxy::TelegramConnectionResponse)
    expect(result.next_step).to include("admin")

    expect(WebMock).to have_requested(:post, "#{BASE_URL}/api/profile_groups/pg-1/initialize_connection")
      .with { |req|
        body = JSON.parse(req.body, symbolize_names: true)
        body == { platform: "telegram", bot_token: "123:ABC" }
      }
  end
end
