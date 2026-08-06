module PostProxy
  class Error < StandardError
    attr_reader :status_code, :response

    def initialize(message, status_code: nil, response: nil)
      super(message)
      @status_code = status_code
      @response = response
    end
  end

  class AuthenticationError < Error; end
  class NotFoundError < Error; end

  # 409. Raised for a duplicate submission (`response[:duplicate_post_id]`), a
  # backfill that is already running (`response[:profile_sync_id]`), or a
  # request whose Idempotency-Key is still in flight.
  class ConflictError < Error; end

  class ValidationError < Error; end
  class BadRequestError < Error; end
end
