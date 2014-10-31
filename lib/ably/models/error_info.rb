module Ably::Models
  # An exception type encapsulating error information containing
  # an Ably-specific error code and generic status code.
  #
  # @!attribute [r] message
  #   @return [String] Additional reason information, where available
  # @!attribute [r] code
  #   @return [Integer] Ably error code (see ably-common/protocol/errors.json)
  # @!attribute [r] status
  #   @return [Integer] HTTP Status Code corresponding to this error, where applicable
  # @!attribute [r] hash
  #   @return [Hash] Access the protocol message Hash object ruby'fied to use symbolized keys
  #
  class ErrorInfo
    include Shared
    include Ably::Modules::Conversions

    def initialize(hash_object)
      @raw_hash_object = hash_object
      @hash_object     = IdiomaticRubyWrapper(hash_object.clone.freeze)
    end

    %w( message code status_code ).each do |attribute|
      define_method attribute do
        hash[attribute.to_sym]
      end
    end
    alias_method :status, :status_code

    def hash
      @hash_object
    end
    alias_method :to_json, :hash

    def to_s
      "Error: #{message} (code: #{code}, status_code: #{status_code})"
    end
  end
end