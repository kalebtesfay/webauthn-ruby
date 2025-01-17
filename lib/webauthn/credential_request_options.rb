# frozen_string_literal: true

require "webauthn/credential_options"

module WebAuthn
  def self.credential_request_options
    CredentialRequestOptions.new.to_h
  end

  class CredentialRequestOptions < CredentialOptions
    attr_accessor :allow_credentials, :extensions, :user_verification

    def initialize(allow_credentials: [], extensions: nil, user_verification: nil)
      @allow_credentials = allow_credentials
      @extensions = extensions
      @user_verification = user_verification
    end

    def to_h
      options = { challenge: challenge, allowCredentials: allow_credentials }

      if extensions
        options[:extensions] = extensions
      end

      if user_verification
        options[:userVerification] = user_verification
      end

      options
    end
  end
end
