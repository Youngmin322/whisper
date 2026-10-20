require "base64"
require "time"

module WhisperDeploy
  PROJECT_ROOT = File.expand_path("..", __dir__).freeze
  APP_IDENTIFIER = "co.kr.youngmin.Whisper".freeze
  TEAM_ID = "5R33532VPH".freeze

  def self.required(name)
    value = ENV[name]
    raise "Missing deployment secret: #{name}" if value.nil? || value.strip.empty?
    value
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

  def self.review_arguments!(version, build)
    raise "Specify an exact app version" unless /\A\d{1,4}(\.\d{1,3}){1,2}\z/.match?(version.to_s)
    raise "Specify an exact build number" unless /\A\d{1,4}(\.\d{1,2}){0,2}\z/.match?(build.to_s)
    [version, build]
  end
end
