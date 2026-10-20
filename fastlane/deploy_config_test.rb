require "minitest/autorun"
require_relative "deploy_config"

class DeployConfigTest < Minitest::Test
  def profile
    { "UUID" => "test-profile", "TeamIdentifier" => [WhisperDeploy::TEAM_ID],
      "ExpirationDate" => "2099-01-01T00:00:00Z",
      "Entitlements" => { "application-identifier" => "#{WhisperDeploy::TEAM_ID}.#{WhisperDeploy::APP_IDENTIFIER}", "get-task-allow" => false } }
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
