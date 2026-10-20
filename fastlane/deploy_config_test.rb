require "minitest/autorun"
require_relative "deploy_config"

class DeployConfigTest < Minitest::Test
  def profile
    { "UUID" => "test-profile", "TeamIdentifier" => [WhisperDeploy::TEAM_ID],
      "ExpirationDate" => "2099-01-01T00:00:00Z",
      "Entitlements" => { "application-identifier" => "#{WhisperDeploy::TEAM_ID}.#{WhisperDeploy::APP_IDENTIFIER}", "get-task-allow" => false } }
  end

  def test_individual_key_authentication_does_not_require_an_issuer
    options = WhisperDeploy.individual_api_key_options(env: {
      "ASC_KEY_ID" => "EXAMPLE123", "ASC_KEY_P8_BASE64" => Base64.strict_encode64("test-key")
    })
    assert_nil options.fetch(:issuer_id)
    assert_equal "EXAMPLE123", options.fetch(:key_id)
    assert_equal "test-key", Base64.strict_decode64(options.fetch(:key_content))
    assert options.fetch(:is_key_content_base64)
  end

  def test_team_issuer_environment_cannot_override_individual_authentication
    %w[ASC_ISSUER_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID SPACESHIP_CONNECT_API_ISSUER_ID].each do |name|
      error = assert_raises(RuntimeError) do
        WhisperDeploy.individual_api_key_options(env: {
          "ASC_KEY_ID" => "EXAMPLE123", "ASC_KEY_P8_BASE64" => "test-key", name => "unwanted-team-issuer"
        })
      end
      assert_includes error.message, name
      refute_includes error.message, "unwanted-team-issuer"
    end
  end

  def test_individual_key_requires_both_registered_secrets
    %w[ASC_KEY_ID ASC_KEY_P8_BASE64].each do |missing|
      secrets = { "ASC_KEY_ID" => "EXAMPLE123", "ASC_KEY_P8_BASE64" => "test-key" }
      secrets.delete(missing)
      error = assert_raises(RuntimeError) { WhisperDeploy.individual_api_key_options(env: secrets) }
      assert_includes error.message, missing
    end
  end

  def test_matching_distribution_profile
    assert_equal "test-profile", WhisperDeploy.validate_profile!(profile)
  end

  def test_profile_for_another_app_is_rejected
    candidate = profile
    candidate["Entitlements"]["application-identifier"] = "wrong.app"
    assert_raises(RuntimeError) { WhisperDeploy.validate_profile!(candidate) }
  end

  def test_development_adhoc_and_enterprise_profiles_are_rejected
    [{ "ProvisionedDevices" => [] }, { "ProvisionsAllDevices" => true }].each do |fields|
      assert_raises(RuntimeError) { WhisperDeploy.validate_profile!(profile.merge(fields)) }
    end
    candidate = profile
    candidate["Entitlements"]["get-task-allow"] = true
    assert_raises(RuntimeError) { WhisperDeploy.validate_profile!(candidate) }
  end

  def test_expired_profile_is_rejected
    assert_raises(RuntimeError) { WhisperDeploy.validate_profile!(profile.merge("ExpirationDate" => "2000-01-01T00:00:00Z")) }
  end

  def test_review_requires_exact_version_and_build
    assert_equal ["2.0.1", "42"], WhisperDeploy.review_arguments!("2.0.1", "42")
    [nil, "", "latest", "42;echo no"].each do |build|
      assert_raises(RuntimeError) { WhisperDeploy.review_arguments!("2.0.1", build) }
    end
  end
end
