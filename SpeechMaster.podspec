Pod::Spec.new do |s|
  s.name             = 'SpeechMaster'
  s.version          = '0.2.0'
  s.summary          = 'iOS Speech Recognition and Text to Speech made easy'
  s.description      = 'iOS Speech Recognition and Text to Speech made easy in Swift'

  s.homepage         = 'https://github.com/iGenius-Srl/SpeechMaster'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'mooncoders' => 'hello@mooncoders.co' }
  s.source           = { :git => 'https://github.com/MoonCoders/SpeechMaster.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/MoonCoders'

  s.source_files = 'SpeechMaster/Classes/**/*'

  s.ios.deployment_target = '10.0'

  s.ios.frameworks = 'AVFoundation', 'Speech'

end
