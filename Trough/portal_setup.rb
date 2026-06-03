#!/usr/bin/env ruby
# Set up App ID + App Group + capabilities for the widget via spaceship ConnectAPI.
require 'spaceship'

KEY = File.expand_path('fastlane/AuthKey_K34HFNJTXH.p8', __dir__)
token = Spaceship::ConnectAPI::Token.create(
  key_id: 'K34HFNJTXH', issuer_id: '69a6de84-f289-47e3-e053-5b8c7c11a4d1', filepath: KEY
)
Spaceship::ConnectAPI.token = token
puts "AUTH ok"

APP    = 'app.trough.ios'
WIDGET = 'app.trough.ios.widget'
GROUP  = 'group.app.trough.ios'

def find_bid(identifier)
  Spaceship::ConnectAPI::BundleId.all.find { |b| b.identifier == identifier }
end

# 1) Widget App ID
widget_bid = find_bid(WIDGET)
if widget_bid
  puts "WIDGET App ID exists: #{widget_bid.id}"
else
  begin
    widget_bid = Spaceship::ConnectAPI::BundleId.create(name: 'Trough Widget', identifier: WIDGET, platform: Spaceship::ConnectAPI::Platform::IOS)
    puts "WIDGET App ID CREATED: #{widget_bid.id}"
  rescue => e
    puts "WIDGET create ERROR: #{e.class}: #{e.message}"
  end
end

# 2) App Group entity — try ConnectAPI first, then Portal
group_obj = nil
begin
  existing_group = find_bid(GROUP)
  if existing_group
    puts "GROUP appears in bundleIds: #{existing_group.id}"
    group_obj = existing_group
  end
rescue => e
  puts "GROUP lookup (connectapi) ERROR: #{e.class}: #{e.message}"
end

unless group_obj
  begin
    # Legacy Portal app group, bridged through the ConnectAPI token if supported
    groups = Spaceship::Portal::AppGroup.all rescue nil
    if groups
      group_obj = groups.find { |g| g.app_group_id == GROUP || g.group_id == GROUP rescue false }
      puts group_obj ? "GROUP exists (portal): #{group_obj.app_group_id}" : "GROUP not found in portal list (#{groups.size} groups)"
      unless group_obj
        group_obj = Spaceship::Portal::AppGroup.create!(group_id: GROUP, name: 'Trough App Group')
        puts "GROUP CREATED (portal): #{group_obj.app_group_id}"
      end
    else
      puts "Portal::AppGroup.all returned nil (token likely not valid for legacy portal)"
    end
  rescue => e
    puts "GROUP create (portal) ERROR: #{e.class}: #{e.message}"
  end
end

# 3) Enable APP_GROUPS capability on both App IDs
[[APP, find_bid(APP)], [WIDGET, widget_bid]].each do |ident, bid|
  next unless bid
  begin
    caps = bid.get_capabilities rescue []
    has = caps.any? { |c| c.id.to_s.include?('APP_GROUPS') || c.capability_type.to_s.include?('APP_GROUPS') rescue false }
    if has
      puts "#{ident}: APP_GROUPS already enabled"
    else
      bid.create_capability(Spaceship::ConnectAPI::BundleIdCapability::Type::APP_GROUPS)
      puts "#{ident}: APP_GROUPS capability ENABLED"
    end
  rescue => e
    puts "#{ident}: capability ERROR: #{e.class}: #{e.message}"
  end
end

puts "DONE"
