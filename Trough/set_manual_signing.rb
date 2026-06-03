#!/usr/bin/env ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('Trough.xcodeproj')
TEAM = '3N9RY9EG8V'

cfg = {
  'Trough'       => 'app.trough.ios AppStore',
  'TroughWidget' => 'app.trough.ios.widget AppStore',
}

cfg.each do |target_name, profile_name|
  t = project.targets.find { |x| x.name == target_name }
  abort "missing target #{target_name}" unless t
  t.build_configurations.each do |c|
    next unless c.name == 'Release'  # Release only; leave Debug/simulator on Automatic
    bs = c.build_settings
    bs['CODE_SIGN_STYLE'] = 'Manual'
    bs['DEVELOPMENT_TEAM'] = TEAM
    bs['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
    bs['PROVISIONING_PROFILE_SPECIFIER'] = profile_name
    puts "#{target_name}/Release -> Manual, profile '#{profile_name}'"
  end
end

project.save
puts 'saved'
