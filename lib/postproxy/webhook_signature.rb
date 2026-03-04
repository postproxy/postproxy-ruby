require "openssl"

module PostProxy
  module WebhookSignature
    def self.verify(payload, signature_header, secret)
      parts = signature_header.split(",").map { |p| p.split("=", 2) }.to_h
      timestamp = parts["t"]
      expected = parts["v1"]

      return false if timestamp.nil? || expected.nil?

      signed_payload = "#{timestamp}.#{payload}"
      computed = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)

      secure_compare(computed, expected)
    end

    private_class_method def self.secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack("C*")
      r = b.unpack("C*")
      result = 0
      l.zip(r) { |x, y| result |= x ^ y }
      result.zero?
    end
  end
end
