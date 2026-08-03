Pod::Spec.new do |s|
  s.name = 'NovellaRs'
  s.version = '0.1.0'
  s.summary = 'Rust-backed reader support for Novella'
  s.description = 'Rust-backed WOFF2 conversion and invisible-glyph extraction for reader fonts.'
  s.license = { type: 'MIT' }
  s.author = { 'Novella' => 'dev@lightnovel.life' }
  s.homepage = 'https://github.com/Kanscape/Novella'
  s.source = { git: 'https://github.com/Kanscape/Novella.git' }
  s.platforms = { ios: '16.4' }
  s.swift_version = '5.9'
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.{h,m,mm,swift}'
  s.vendored_frameworks = 'Frameworks/NovellaRs.xcframework'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end
