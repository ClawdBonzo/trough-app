#!/usr/bin/env ruby
# Probe: can this App Store Connect API key manage App IDs + App Groups via spaceship?
require 'spaceship'

key_path = File.expand_path('fastlane/AuthKey_K34HFNJTXH.p8', __dir__)
token = Spaceship::ConnectAPI::Token.create(
  key_id: 'K34HFNJTXH',
  issuer_id: '69a6de84-f289-47e3-e053-5b8c7c11a4d1',
  filepath: key_path
)
Spaceship::ConnectAPI.token = token
puts "AUTH: token created OK"

begin
  bids = Spaceship::ConnectAPI::BundleId.all
  puts "BUNDLE_IDS (#{bids.size}):"
  bids.each { |b| puts "  - #{b.identifier}  [#{b.name}]  id=#{b.id}" }
rescue => e
  puts "BUNDLE_ID list ERROR: #{e.class}: #{e.message}"
end

# Does spaceship expose App Groups under ConnectAPI?
puts "HAS ConnectAPI::AppGroup? #{Spaceship::ConnectAPI.const_defined?(:AppGroup) rescue false}"

# Try legacy Portal app_group listing through the token, if supported
begin
  groups = Spaceship::ConnectAPI.get_bundle_ids rescue nil
  puts "get_bundle_ids works: #{!groups.nil?}"
rescue => e
  puts "get_bundle_ids ERROR: #{e.class}: #{e.message}"
end

# Inspect available capability types
begin
  require 'spaceship/connect_api/models/bundle_id_capability'
  puts "Capability types include APP_GROUPS? #{Spaceship::ConnectAPI::BundleIdCapability::Type.constants.include?(:APP_GROUPS) rescue 'n/a'}"
  puts "Capability constants: #{Spaceship::ConnectAPI::BundleIdCapability::Type.constants.join(', ')}" rescue nil
rescue => e
  puts "capability introspection ERROR: #{e.class}: #{e.message}"
end
