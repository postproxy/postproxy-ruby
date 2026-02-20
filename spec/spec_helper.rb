require "postproxy"
require "webmock/rspec"
require "json"

WebMock.disable_net_connect!

BASE_URL = "https://api.postproxy.dev"

def stub_api(method, path, status: 200, body: {}, query: nil)
  stub = stub_request(method, "#{BASE_URL}/api#{path}")
  stub = stub.with(query: query) if query
  stub.to_return(
    status: status,
    body: body.to_json,
    headers: { "Content-Type" => "application/json" }
  )
end

def new_client(api_key: "test-key", profile_group_id: nil)
  PostProxy::Client.new(api_key, profile_group_id: profile_group_id)
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
