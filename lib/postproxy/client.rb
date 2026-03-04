require "faraday"
require "faraday/multipart"
require "json"
require_relative "resources/posts"
require_relative "resources/profiles"
require_relative "resources/profile_groups"
require_relative "resources/webhooks"

module PostProxy
  class Client
    attr_reader :api_key, :base_url, :profile_group_id

    def initialize(api_key, base_url: DEFAULT_BASE_URL, profile_group_id: nil, faraday_client: nil)
      @api_key = api_key
      @base_url = base_url
      @profile_group_id = profile_group_id
      @faraday_client = faraday_client
      @posts = nil
      @profiles = nil
      @profile_groups = nil
      @webhooks = nil
    end

    def posts
      @posts ||= Resources::Posts.new(self)
    end

    def profiles
      @profiles ||= Resources::Profiles.new(self)
    end

    def profile_groups
      @profile_groups ||= Resources::ProfileGroups.new(self)
    end

    def webhooks
      @webhooks ||= Resources::Webhooks.new(self)
    end

    def request(method, path, params: nil, json: nil, data: nil, files: nil, profile_group_id: nil)
      url = "/api#{path}"

      query = {}
      pgid = profile_group_id || @profile_group_id
      query[:profile_group_id] = pgid if pgid
      query.merge!(params) if params

      response = if files
                   conn = multipart_connection
                   parts = []
                   data&.each { |k, v| parts << [k.to_s, v.to_s] }
                   files.each do |field, filename, io, content_type|
                     if io.nil?
                       # Plain text part (filename holds the string value)
                       parts << [field, filename]
                     elsif io.is_a?(String)
                       # Plain text part
                       parts << [field, io]
                     else
                       # File upload
                       parts << [field, Faraday::Multipart::FilePart.new(io, content_type, filename)]
                     end
                   end
                   # Build payload preserving duplicate keys
                   payload = parts.each_with_object({}) do |(key, val), h|
                     if h.key?(key)
                       h[key] = [h[key]] unless h[key].is_a?(Array)
                       h[key] << val
                     else
                       h[key] = val
                     end
                   end
                   conn.send(method, url) do |req|
                     req.params = query unless query.empty?
                     req.body = payload
                   end
                 else
                   conn = json_connection
                   conn.send(method, url) do |req|
                     req.params = query unless query.empty?
                     req.body = json.to_json if json
                   end
                 end

      handle_response(response)
    end

    private

    def json_connection
      @faraday_client || Faraday.new(url: @base_url) do |f|
        f.request :url_encoded
        f.headers["Authorization"] = "Bearer #{@api_key}"
        f.headers["Content-Type"] = "application/json"
        f.adapter Faraday.default_adapter
      end
    end

    def multipart_connection
      @faraday_client || Faraday.new(url: @base_url) do |f|
        f.request :multipart
        f.headers["Authorization"] = "Bearer #{@api_key}"
        f.adapter Faraday.default_adapter
      end
    end

    def handle_response(response)
      case response.status
      when 200..299
        return nil if response.status == 204
        return nil if response.body.nil? || response.body.empty?
        JSON.parse(response.body, symbolize_names: true)
      when 401
        body = parse_error_body(response)
        raise AuthenticationError.new(
          error_message(body),
          status_code: response.status,
          response: body
        )
      when 404
        body = parse_error_body(response)
        raise NotFoundError.new(
          error_message(body),
          status_code: response.status,
          response: body
        )
      when 422
        body = parse_error_body(response)
        raise ValidationError.new(
          error_message(body),
          status_code: response.status,
          response: body
        )
      when 400
        body = parse_error_body(response)
        raise BadRequestError.new(
          error_message(body),
          status_code: response.status,
          response: body
        )
      else
        body = parse_error_body(response)
        raise Error.new(
          error_message(body),
          status_code: response.status,
          response: body
        )
      end
    end

    def parse_error_body(response)
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError, TypeError
      { error: response.body }
    end

    def error_message(body)
      body[:message] || body[:error]
    end
  end
end
