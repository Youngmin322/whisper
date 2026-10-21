require "base64"
require "time"

module WhisperDeploy
  PROJECT_ROOT = File.expand_path("..", __dir__).freeze
  APP_IDENTIFIER = "co.kr.youngmin.Whisper".freeze
  TEAM_ID = "5R33532VPH".freeze

  def self.required(name, env: ENV)
    value = env[name]
    raise "Missing deployment secret: #{name}" if value.nil? || value.strip.empty?
    value
  end

  def self.individual_api_key_options(env: ENV)
    issuer_names = %w[ASC_ISSUER_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID SPACESHIP_CONNECT_API_ISSUER_ID]
    conflict = issuer_names.find { |name| env.key?(name) }
    raise "Use an individual API key without an issuer ID; unset #{conflict}" if conflict

    {
      key_id: required("ASC_KEY_ID", env: env),
      issuer_id: nil,
      key_content: required("ASC_KEY_P8_BASE64", env: env),
      is_key_content_base64: true,
      duration: 1200,
      in_house: false
    }
  end

  def self.decode_secret(name)
    Base64.strict_decode64(required(name).delete("\r\n"))
  rescue ArgumentError
    raise "Invalid base64 deployment secret: #{name}"
  end

  def self.validate_profile!(profile, now: Time.now)
    identifier = profile.fetch("Entitlements", {})["application-identifier"]
    raise "Provisioning profile does not match Whisper" unless identifier == "#{TEAM_ID}.#{APP_IDENTIFIER}"
    raise "Provisioning profile has the wrong team" unless profile.fetch("TeamIdentifier", []).include?(TEAM_ID)
    raise "Use an App Store distribution profile" if profile.key?("ProvisionedDevices") || profile["ProvisionsAllDevices"] || profile.fetch("Entitlements", {})["get-task-allow"]
    raise "Provisioning profile has expired" unless Time.parse(profile.fetch("ExpirationDate").to_s) > now
    raise "Provisioning profile is missing its UUID" if profile["UUID"].to_s.empty?
    profile.fetch("UUID")
  end

  # Some internal groups already receive the build automatically, and Apple's
  # assignment endpoint can reject an otherwise successful internal distribution.
  # Success requires the exact uploaded build to be ready and visible in the group.
  def self.distribute_internal!(group:, find_build:, distribute:, attempts: 12, interval: 5, sleeper: ->(seconds) { sleep(seconds) })
    raise "Use an internal TestFlight group" unless group.is_internal_group
    groups = group.has_access_to_all_builds == true ? [] : [group.id]
    begin
      distribute.call(groups)
    rescue StandardError => error
      raise unless error.message.include?("Cannot add internal group to a build")
    end

    attempts.times do |attempt|
      build = find_build.call
      internal_state = build&.build_beta_detail&.internal_build_state
      if build && build.processing_state == "VALID" && !build.expired && %w[READY_FOR_BETA_TESTING IN_BETA_TESTING].include?(internal_state)
        return build if group.fetch_builds.any? { |candidate| candidate.id == build.id }
      end
      sleeper.call(interval) if attempt < attempts - 1
    end
    raise "Could not verify the uploaded build in the configured internal TestFlight group; check the existing build before uploading again"
  end

  def self.review_arguments!(version, build)
    raise "Specify an exact app version" unless /\A\d{1,4}(\.\d{1,3}){1,2}\z/.match?(version.to_s)
    raise "Specify an exact build number" unless /\A\d{1,4}(\.\d{1,2}){0,2}\z/.match?(build.to_s)
    [version, build]
  end
end
