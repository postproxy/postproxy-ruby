require "spec_helper"

RSpec.describe "Profile stats endpoint" do
  let(:client) { new_client }

  it "calls GET /profiles/:id/stats with placement_id" do
    stub_api(:get, "/profiles/pf1/stats",
      query: { placement_id: "org_1", from: "2026-04-01T00:00:00Z" },
      body: {
        data: {
          profile_id: "pf1",
          platform: "linkedin",
          placement_id: "org_1",
          records: [
            { stats: { followerCount: 100 }, recorded_at: "2026-05-12T00:00:00Z" }
          ]
        }
      })

    result = client.profiles.get_profile_stats("pf1",
      placement_id: "org_1",
      from: "2026-04-01T00:00:00Z"
    )

    expect(result).to be_a(PostProxy::ProfileStatsResponse)
    expect(result.data.profile_id).to eq("pf1")
    expect(result.data.records.first.stats[:followerCount]).to eq(100)
  end

  it "omits placement_id for non-placement networks" do
    stub_api(:get, "/profiles/bsky1/stats", body: {
      data: { profile_id: "bsky1", platform: "bluesky", placement_id: nil, records: [] }
    })

    result = client.profiles.get_profile_stats("bsky1")
    expect(result.data.placement_id).to be_nil
  end
end
