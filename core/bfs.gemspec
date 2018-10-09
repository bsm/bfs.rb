Gem::Specification.new do |s|
  s.name        = 'bfs'
  s.version     = '0.1.0'
  s.platform    = Gem::Platform::RUBY

  s.licenses    = ['Apache-2.0']
  s.summary     = 'Multi-platform cloud bucket adapter'
  s.description = 'Minimalist abstraction for bucket storage'

  s.authors     = ['Dimitrij Denissenko']
  s.email       = 'dimitrij@blacksquaremedia.com'
  s.homepage    = 'https://github.com/bsm/bfs.rb'

  s.executables   = []
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 2.2.0'
end
