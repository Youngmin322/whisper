require "minitest/autorun"
require_relative "deploy_config"

class DeployConfigTest < Minitest::Test
  Build = Struct.new(:id, :processing_state, :expired, :ready) do
    def ready_for_internal_testing?; ready; end
  end
  Group = Struct.new(:id, :is_internal_group, :has_access_to_all_builds, :builds) do
    def fetch_builds; builds; end
  end

  def ready_build
    Build.new("uploaded-build", "VALID", false, true)
  end

  def verify_distribution(group:, build: ready_build, **options, &distribute)
    WhisperDeploy.distribute_internal!(group: group, find_build: -> { build },
      distribute: distribute || ->(_) {}, attempts: 1, **options)
  end

  def test_automatic_internal_group_does_not_receive_an_assignment_request
    build = ready_build
    group = Group.new("internal", true, true, [build])
    verified = verify_distribution(group: group, build: build) { |groups| assert_empty groups }
    assert_equal build, verified
  end

  def test_manual_internal_group_is_selected_and_verified
    build = ready_build
    group = Group.new("internal", true, false, [build])
    verified = verify_distribution(group: group, build: build) { |groups| assert_equal ["internal"], groups }
    assert_equal build, verified
  end

  def test_known_assignment_error_is_recovered_only_after_membership_verification
    build = ready_build
    group = Group.new("internal", true, false, [build])
    assert_equal build, verify_distribution(group: group, build: build) {
      raise "Builds cannot be assigned to this internal group. - Cannot add internal group to a build."
    }
  end

  def test_known_assignment_error_without_the_build_is_not_success
    group = Group.new("internal", true, false, [])
    assert_raises(RuntimeError) do
      verify_distribution(group: group) { raise "Cannot add internal group to a build" }
    end
  end

  def test_other_api_errors_are_not_suppressed
    group = Group.new("internal", true, false, [ready_build])
    error = assert_raises(RuntimeError) { verify_distribution(group: group) { raise "Permission denied" } }
    assert_equal "Permission denied", error.message
  end

  def test_failed_expired_unready_and_unrelated_builds_cannot_be_verified
    [Build.new("uploaded-build", "INVALID", false, true),
     Build.new("uploaded-build", "VALID", true, true),
     Build.new("uploaded-build", "VALID", false, false), nil].each do |build|
      group = Group.new("internal", true, false, [ready_build])
      assert_raises(RuntimeError) { verify_distribution(group: group, build: build) }
    end
    group = Group.new("internal", true, false, [Build.new("another-build", "VALID", false, true)])
    assert_raises(RuntimeError) { verify_distribution(group: group) }
  end

  def test_readiness_is_polled_with_a_bounded_wait
    build = ready_build
    group = Group.new("internal", true, true, [build])
    candidates = [nil, Build.new(build.id, "PROCESSING", false, false), build]
    waits = []
    verified = WhisperDeploy.distribute_internal!(group: group, find_build: -> { candidates.shift },
      distribute: ->(groups) { assert_empty groups }, attempts: 3, interval: 5, sleeper: ->(seconds) { waits << seconds })
    assert_equal build, verified
    assert_equal [5, 5], waits
  end

  def test_external_group_is_rejected_before_distribution
    group = Group.new("external", false, false, [])
    assert_raises(RuntimeError) { verify_distribution(group: group) { flunk "must not distribute" } }
  end

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
      ["", " ", "unwanted-team-issuer"].each do |value|
        error = assert_raises(RuntimeError) do
          WhisperDeploy.individual_api_key_options(env: {
            "ASC_KEY_ID" => "EXAMPLE123", "ASC_KEY_P8_BASE64" => "test-key", name => value
          })
        end
        assert_includes error.message, name
        refute_includes error.message, "unwanted-team-issuer"
      end
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
