require "spec_helper"

RSpec.describe PostProxy::Resources::GoogleBusiness do
  let(:client) { new_client }
  let(:gbp) { client.google_business }
  let(:base) { "#{BASE_URL}/api/profiles/prof_gbp/google_business" }

  def stub_gbp(method, action, body: {}, query: nil, json: nil)
    stub = stub_request(method, "#{base}/#{action}")
    stub = stub.with(query: query) if query
    stub = stub.with(body: json) if json
    stub.to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  it "reads the location with a read mask" do
    stub = stub_gbp(:get, "location", body: { title: "Cafe" },
      query: { location_id: "loc_1", read_mask: "title,phoneNumbers" })

    result = gbp.location("prof_gbp", "loc_1", read_mask: "title,phoneNumbers")
    expect(stub).to have_been_requested
    expect(result[:title]).to eq("Cafe")
  end

  it "updates the location with a field mask" do
    stub = stub_gbp(:patch, "update_location",
      json: { location_id: "loc_1", websiteUri: "https://acme.test", fields: ["websiteUri"] })

    gbp.update_location("prof_gbp", "loc_1", { websiteUri: "https://acme.test" }, fields: ["websiteUri"])
    expect(stub).to have_been_requested
  end

  it "lists available categories with region code, dropping unset params" do
    stub = stub_gbp(:get, "available_location_categories", body: { categories: [] },
      query: { location_id: "loc_1", region_code: "US", page_size: "50" })

    gbp.available_location_categories("prof_gbp", "loc_1", "US", page_size: 50)
    expect(stub).to have_been_requested
  end

  it "updates hours passing Google's camelCase shape" do
    regular_hours = {
      periods: [{ openDay: "MONDAY", openTime: { hours: 9 }, closeDay: "MONDAY", closeTime: { hours: 17 } }]
    }
    stub = stub_gbp(:patch, "update_hours",
      json: { location_id: "loc_1", fields: ["regularHours"], regularHours: regular_hours })

    gbp.update_hours("prof_gbp", "loc_1", fields: ["regularHours"], regular_hours: regular_hours)
    expect(stub).to have_been_requested
  end

  it "updates attributes, service list and food menus" do
    attrs = stub_gbp(:patch, "update_attributes", json: {
      location_id: "loc_1",
      attributes: [{ name: "attributes/has_wifi", values: [true] }],
      attribute_mask: ["attributes/has_wifi"]
    })
    services = stub_gbp(:patch, "update_service_list",
      json: { location_id: "loc_1", serviceItems: [{ freeFormServiceItem: {} }] })
    menus = stub_gbp(:patch, "update_food_menus",
      json: { location_id: "loc_1", menus: [{ labels: [] }], fields: ["menus"] })

    gbp.update_attributes("prof_gbp", "loc_1", [{ name: "attributes/has_wifi", values: [true] }],
      attribute_mask: ["attributes/has_wifi"])
    gbp.update_service_list("prof_gbp", "loc_1", [{ freeFormServiceItem: {} }])
    gbp.update_food_menus("prof_gbp", "loc_1", [{ labels: [] }], fields: ["menus"])

    [attrs, services, menus].each { |s| expect(s).to have_been_requested }
  end

  it "reads attributes, services and menus" do
    stubs = [
      stub_gbp(:get, "attributes", query: { location_id: "loc_1" }),
      stub_gbp(:get, "available_attributes", query: { location_id: "loc_1", show_all: "true" }),
      stub_gbp(:get, "service_list", query: { location_id: "loc_1" }),
      stub_gbp(:get, "food_menus", query: { location_id: "loc_1", fields: "menus,name" })
    ]

    gbp.attributes("prof_gbp", "loc_1")
    gbp.available_attributes("prof_gbp", "loc_1", show_all: true)
    gbp.service_list("prof_gbp", "loc_1")
    gbp.food_menus("prof_gbp", "loc_1", fields: %w[menus name])

    stubs.each { |s| expect(s).to have_been_requested }
  end

  it "manages place action links" do
    name = "locations/1/placeActionLinks/2"
    stubs = [
      stub_gbp(:get, "place_action_links", query: { location_id: "loc_1" }),
      stub_gbp(:get, "available_place_action_types", query: { location_id: "loc_1", language_code: "en" }),
      stub_gbp(:post, "create_place_action_link", json: {
        location_id: "loc_1", uri: "https://book.test", place_action_type: "APPOINTMENT", is_preferred: true
      }),
      stub_gbp(:patch, "update_place_action_link", json: {
        location_id: "loc_1", name: name, fields: ["uri"], uri: "https://book2.test"
      }),
      stub_gbp(:delete, "delete_place_action_link", query: { location_id: "loc_1", name: name })
    ]

    gbp.place_action_links("prof_gbp", "loc_1")
    gbp.available_place_action_types("prof_gbp", "loc_1", language_code: "en")
    gbp.create_place_action_link("prof_gbp", "loc_1",
      uri: "https://book.test", place_action_type: "APPOINTMENT", is_preferred: true)
    gbp.update_place_action_link("prof_gbp", "loc_1", name, fields: ["uri"], uri: "https://book2.test")
    gbp.delete_place_action_link("prof_gbp", "loc_1", name)

    stubs.each { |s| expect(s).to have_been_requested }
  end

  it "manages media" do
    stubs = [
      stub_gbp(:get, "media", query: { location_id: "loc_1", page_size: "10" }),
      stub_gbp(:post, "create_media", json: {
        location_id: "loc_1", media_url: "https://img.test/a.jpg", category: "COVER", media_format: "PHOTO"
      }),
      stub_gbp(:delete, "delete_media", query: { location_id: "loc_1", media_name: "accounts/1/locations/1/media/9" })
    ]

    gbp.media("prof_gbp", "loc_1", page_size: 10)
    gbp.create_media("prof_gbp", "loc_1", "https://img.test/a.jpg", category: "COVER", media_format: "PHOTO")
    gbp.delete_media("prof_gbp", "loc_1", "accounts/1/locations/1/media/9")

    stubs.each { |s| expect(s).to have_been_requested }
  end
end
