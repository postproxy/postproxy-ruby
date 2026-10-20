require "faraday"
require "faraday/multipart"
require "json"
require_relative "resources/posts"
require_relative "resources/profiles"
require_relative "resources/profile_groups"
require_relative "resources/webhooks"
require_relative "resources/queues"
require_relative "resources/comments"
require_relative "resources/profile_comments"
require_relative "resources/chats"
require_relative "resources/messages"
require_relative "resources/placements"
require_relative "resources/api_keys"
require_relative "resources/google_business"
require_relative "resources/whatsapp_templates"
require_relative "resources/whatsapp"

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
      @queues = nil
      @comments = nil
      @profile_comments = nil
      @chats = nil
      @messages = nil
      @placements = nil
      @api_keys = nil
      @google_business = nil
      @whatsapp_templates = nil
      @whatsapp = nil
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

    def queues
      @queues ||= Resources::Queues.new(self)
    end

    def comments
      @comments ||= Resources::Comments.new(self)
    end

    def profile_comments
      @profile_comments ||= Resources::ProfileComments.new(self)
    end

    def chats
      @chats ||= Resources::Chats.new(self)
    end

    def messages
      @messages ||= Resources::Messages.new(self)
    end

    def placements
      @placements ||= Resources::Placements.new(self)
    end

    def api_keys
      @api_keys ||= Resources::ApiKeys.new(self)
    end

    def google_business
      @google_business ||= Resources::GoogleBusiness.new(self)
    end

    def whatsapp_templates
      @whatsapp_templates ||= Resources::WhatsAppTemplates.new(self)
    end

    def whatsapp
      @whatsapp ||= Resources::WhatsApp.new(self)
    end

    # `raw: true` returns the body bytes and content type instead of parsing
    # JSON (used for binary downloads).
    def request(method, path, params: nil, json: nil, data: nil, files: nil, profile_group_id: nil,
      idempotency_key: nil, headers: nil, raw: false)
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
                   # Build payload preserving duplicate keys. Repeated "foo[]"
                   # parts are grouped under "foo" — Faraday appends "[]" to
                   # each array item itself.
                   grouped = parts.group_by(&:first)
                   payload = grouped.each_with_object({}) do |(key, pairs), h|
                     values = pairs.map(&:last)
                     if values.size == 1
                       h[key] = values.first
                     elsif key.end_with?("[]")
                       h[key.delete_suffix("[]")] = values
                     else
                       h[key] = values
                     end
                   end
                   conn.send(method, url) do |req|
                     req.params = query unless query.empty?
                     req.headers["Idempotency-Key"] = idempotency_key if idempotency_key
                     headers&.each { |k, v| req.headers[k] = v }
                     req.body = payload
                   end
                 else
                   conn = json_connection
                   conn.send(method, url) do |req|
                     req.params = query unless query.empty?
                     req.headers["Idempotency-Key"] = idempotency_key if idempotency_key
                     headers&.each { |k, v| req.headers[k] = v }
                     req.body = json.to_json if json
                   end
                 end

      if raw && (200..299).cover?(response.status)
        return RawResponse.new(data: response.body.to_s.b, content_type: response.headers["content-type"])
      end

      handle_response(response)
    end

    private

    def user_agent
      @user_agent ||= "postproxy-ruby/#{PostProxy::VERSION} (ruby/#{RUBY_VERSION})"
    end

    def json_connection
      @faraday_client || Faraday.new(url: @base_url) do |f|
        f.request :url_encoded
        f.headers["Authorization"] = "Bearer #{@api_key}"
        f.headers["Content-Type"] = "application/json"
        f.headers["User-Agent"] = user_agent
        f.adapter Faraday.default_adapter
      end
    end

    def multipart_connection
      @faraday_client || Faraday.new(url: @base_url) do |f|
        f.request :multipart
        f.headers["Authorization"] = "Bearer #{@api_key}"
        f.headers["User-Agent"] = user_agent
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
      when 403
        body = parse_error_body(response)
        raise ForbiddenError.new(
          error_message(body),
          status_code: response.status,
          response: body
        )
      when 429
        body = parse_error_body(response)
        raise RateLimitError.new(
          error_message(body),
          status_code: response.status,
          response: body,
          retry_after: parse_retry_after(response.headers["retry-after"])
        )
      when 404
        body = parse_error_body(response)
        raise NotFoundError.new(
          error_message(body),
          status_code: response.status,
          response: body
        )
      when 409
        body = parse_error_body(response)
        raise ConflictError.new(
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

    def parse_retry_after(value)
      seconds = Float(value.to_s, exception: false)
      return nil if seconds.nil? || !seconds.finite? || seconds <= 0

      seconds == seconds.to_i ? seconds.to_i : seconds
    end

    def error_message(body)
      body[:message] || body[:error]
    end
  end
end
