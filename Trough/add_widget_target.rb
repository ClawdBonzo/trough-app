#!/usr/bin/env ruby
require 'xcodeproj'

PROJECT = 'Trough.xcodeproj'
TEAM    = '3N9RY9EG8V'
project = Xcodeproj::Project.open(PROJECT)

app = project.targets.find { |t| t.name == 'Trough' }
abort 'ERROR: app target Trough not found' unless app

if project.targets.any? { |t| t.name == 'TroughWidget' }
  puts 'TroughWidget target already exists — nothing to do.'
  exit 0
end

# --- 1) Create the widget extension target -----------------------------------
widget = project.new_target(:app_extension, 'TroughWidget', :ios, '17.0', project.products_group, :swift)

widget.build_configurations.each do |c|
  bs = c.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.trough.ios.widget'
  bs['PRODUCT_NAME']              = '$(TARGET_NAME)'
  bs['DEVELOPMENT_TEAM']          = TEAM
  bs['SWIFT_VERSION']             = '5.9'
  bs['IPHONEOS_DEPLOYMENT_TARGET']= '17.0'
  bs['TARGETED_DEVICE_FAMILY']    = '1'
  bs['INFOPLIST_FILE']            = 'TroughWidget/Info.plist'
  bs['CODE_SIGN_ENTITLEMENTS']    = 'TroughWidget/TroughWidget.entitlements'
  bs['GENERATE_INFOPLIST_FILE']   = 'NO'
  bs['SKIP_INSTALL']              = 'YES'
  bs['CODE_SIGN_STYLE']           = 'Automatic'
  bs['MARKETING_VERSION']         = '1.1.2'
  bs['CURRENT_PROJECT_VERSION']   = '65'
  bs['SWIFT_EMIT_LOC_STRINGS']    = 'YES'
  bs['LD_RUNPATH_SEARCH_PATHS']   = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
end

# --- 2) Widget source files + plist/entitlements refs ------------------------
wgroup = project.main_group.find_subpath('TroughWidget', true)
wgroup.set_source_tree('SOURCE_ROOT')
wgroup.set_path('TroughWidget')

%w[TroughWidgetBundle.swift TroughStreakWidget.swift InjectionLiveActivity.swift].each do |f|
  ref = wgroup.new_reference(f)
  widget.add_file_references([ref])
end
wgroup.new_reference('Info.plist')
wgroup.new_reference('TroughWidget.entitlements')

# --- 3) Shared file (both targets) ------------------------------------------
trough_group = project.main_group.children.find { |g| g.respond_to?(:display_name) && g.display_name == 'Trough' }
abort 'ERROR: Trough group not found' unless trough_group

shared_group = trough_group.find_subpath('Shared', true)
shared_group.set_path('Shared')
shared_ref = shared_group.new_reference('WidgetSharedData.swift')
widget.add_file_references([shared_ref])
app.add_file_references([shared_ref])

# --- 4) App-only bridge files into existing Services group -------------------
services_group = trough_group.find_subpath('Services', true)
%w[WidgetBridge.swift LiveActivityService.swift].each do |f|
  ref = services_group.new_reference(f)
  app.add_file_references([ref])
end

# --- 5) Embed the extension in the app + dependency -------------------------
app.add_dependency(widget)
embed = app.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' }
unless embed
  embed = app.new_copy_files_build_phase('Embed App Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
end
bf = embed.add_file_reference(widget.product_reference, true)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
puts 'OK: TroughWidget target created.'
puts "Targets: #{project.targets.map(&:name).join(', ')}"
puts "Widget sources: #{widget.source_build_phase.files.map { |x| x.file_ref.display_name }.join(', ')}"
puts "App new sources include: WidgetBridge/LiveActivityService/WidgetSharedData"
