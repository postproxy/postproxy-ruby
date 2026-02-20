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
  class ValidationError < Error; end
  class BadRequestError < Error; end
end
