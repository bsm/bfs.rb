Gem::Specification.new do |s|
  s.name        = 'bfs-s3'
  s.version     = File.read(File.expand_path('../.version', __dir__)).strip
  s.platform    = Gem::Platform::RUBY

  s.licenses    = ['Apache-2.0']
  s.summary     = 'S3 bucket adapter for bfs'
  s.description = 'https://github.com/bsm/bfs.rb'

  s.authors     = ['Dimitrij Denissenko']
  s.email       = 'dimitrij@blacksquaremedia.com'
  s.homepage    = 'https://github.com/bsm/bfs.rb'

  s.executables   = []
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 2.2.0'

  s.add_dependency 'aws-sdk-s3'
  s.add_dependency 'bfs'
end
