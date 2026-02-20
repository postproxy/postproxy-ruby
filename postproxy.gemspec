require_relative "lib/postproxy/version"

Gem::Specification.new do |spec|
  spec.name          = "postproxy-sdk"
  spec.version       = PostProxy::VERSION
  spec.authors       = ["PostProxy"]
  spec.email         = ["support@postproxy.dev"]

  spec.summary       = "Ruby client for the PostProxy API"
  spec.description   = "Ruby client for the PostProxy API — manage social media posts, profiles, and profile groups."
  spec.homepage      = "https://postproxy.dev"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = "https://github.com/postproxy/postproxy-ruby"
  spec.metadata["documentation_uri"] = "https://postproxy.dev/getting-started/overview/"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.0"
  spec.add_dependency "faraday-multipart", ">= 1.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
end
