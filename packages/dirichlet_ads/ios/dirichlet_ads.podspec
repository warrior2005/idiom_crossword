Pod::Spec.new do |s|
  s.name = 'dirichlet_ads'
  s.version = '0.1.0'
  s.summary = 'Dirichlet mediation bridge for idiom crossword.'
  s.homepage = 'https://ssp.dirichlet.cn/'
  s.license = { :type => 'Proprietary' }
  s.author = { 'Idiom Crossword' => 'warriorsise@gmail.com' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.platform = :ios, '15.0'
  s.static_framework = true
  s.dependency 'Flutter'
  s.dependency 'DirichletMediationSDK', '5.2.1.5'
  s.dependency 'DirichletMediationAdapterDRA', '5.2.1.5'
  s.frameworks = 'AdSupport', 'AppTrackingTransparency', 'SafariServices', 'WebKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
