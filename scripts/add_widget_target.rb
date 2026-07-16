#!/usr/bin/env ruby
# Runner.xcodeproj에 ShiftWidget 위젯 익스텐션 타깃을 추가한다.
# 로컬에 Xcode가 없어 CI(GitHub Actions)에서 빌드 직전에 실행한다.
# 이미 추가되어 있으면 아무것도 하지 않는다(멱등).

require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

if project.targets.any? { |t| t.name == 'ShiftWidget' }
  puts 'ShiftWidget target already exists — skipping'
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

widget = project.new_target(:app_extension, 'ShiftWidget', :ios, '16.0')

group = project.main_group.find_subpath('ShiftWidget', true)
group.set_source_tree('SOURCE_ROOT')
group.set_path('ShiftWidget')
swift_file = group.new_file('ShiftWidget.swift')
widget.add_file_references([swift_file])

widget.build_configurations.each do |config|
  bs = config.build_settings
  bs['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.shiftplan.ShiftWidget'
  bs['INFOPLIST_FILE'] = 'ShiftWidget/Info.plist'
  bs['GENERATE_INFOPLIST_FILE'] = 'NO'
  bs['SWIFT_VERSION'] = '5.0'
  bs['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
  bs['TARGETED_DEVICE_FAMILY'] = '1,2'
  bs['SKIP_INSTALL'] = 'YES'
  bs['CODE_SIGN_ENTITLEMENTS'] = 'ShiftWidget/ShiftWidget.entitlements'
  bs['PRODUCT_NAME'] = 'ShiftWidget'
  bs['CURRENT_PROJECT_VERSION'] = '1'
  bs['MARKETING_VERSION'] = '1.0.0'
end

# Runner가 위젯을 포함(embed)하도록 설정.
runner.add_dependency(widget)
embed = runner.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
build_file = embed.add_file_reference(widget.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# Flutter의 'Thin Binary' 스크립트 단계 뒤에 임베드가 오면 빌드 그래프에
# 순환이 생긴다. 임베드 단계를 그 앞으로 옮긴다.
phases = runner.build_phases
thin = phases.find { |p| p.display_name.to_s.include?('Thin Binary') }
if thin
  phases.delete(embed)
  phases.insert(phases.index(thin), embed)
end

# Runner에 App Group entitlements 연결.
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

project.save
puts 'ShiftWidget target added'
