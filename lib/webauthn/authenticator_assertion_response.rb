# frozen_string_literal: true

require "cose/key"
require "webauthn/attestation_statement/fido_u2f/public_key"
require "webauthn/authenticator_response"

module WebAuthn
  class CredentialVerificationError < VerificationError; end
  class SignatureVerificationError < VerificationError; end

  class AuthenticatorAssertionResponse < AuthenticatorResponse
    def initialize(credential_id:, authenticator_data:, signature:, **options)
      super(options)

      @credential_id = credential_id
      @authenticator_data_bytes = authenticator_data
      @signature = signature
    end

    def verify(original_challenge, original_origin, allowed_credentials:, rp_id: nil)
      super(original_challenge, original_origin, rp_id: rp_id)

      verify_item(:credential, allowed_credentials)
      verify_item(:signature, credential_public_key(allowed_credentials))

      true
    end

    def authenticator_data
      @authenticator_data ||= WebAuthn::AuthenticatorData.new(authenticator_data_bytes)
    end

    private

    attr_reader :credential_id, :authenticator_data_bytes, :signature

    def valid_signature?(public_key_bytes)
      key =
        if WebAuthn::AttestationStatement::FidoU2f::PublicKey.uncompressed_point?(public_key_bytes)
          # Gem version v1.11.0 and lower, used to behave so that Credential#public_key
          # returned an EC P-256 uncompressed point.
          #
          # Because of https://github.com/cedarcode/webauthn-ruby/issues/137 this was changed
          # and Credential#public_key started returning the unchanged COSE_Key formatted
          # credentialPublicKey (as in https://www.w3.org/TR/webauthn/#credentialpublickey).
          #
          # Given that the credential public key is expected to be stored long-term by the gem
          # user and later be passed as one of the allowed_credentials arguments in the
          # AuthenticatorAssertionResponse.verify call, we then need to support the two formats.
          group = OpenSSL::PKey::EC::Group.new("prime256v1")
          key = OpenSSL::PKey::EC.new(group)
          public_key_bn = OpenSSL::BN.new(public_key_bytes, 2)
          public_key = OpenSSL::PKey::EC::Point.new(group, public_key_bn)
          key.public_key = public_key

          key
        else
          COSE::Key.deserialize(public_key_bytes).to_pkey
        end

      key.verify(
        "SHA256",
        signature,
        authenticator_data_bytes + client_data.hash
      )
    end

    def valid_credential?(allowed_credentials)
      allowed_credential_ids = allowed_credentials.map { |credential| credential[:id] }

      allowed_credential_ids.include?(credential_id)
    end

    def credential_public_key(allowed_credentials)
      matched_credential = allowed_credentials.find do |credential|
        credential[:id] == credential_id
      end

      matched_credential[:public_key]
    end

    def type
      WebAuthn::TYPES[:get]
    end
  end
end
