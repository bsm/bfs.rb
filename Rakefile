require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'bundler/gem_helper'

PACKAGES = Dir['*/*.gemspec'].map {|fn| File.dirname(fn) }.freeze

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = '*/spec/**{,/*/**}/*_spec.rb'
end

RuboCop::RakeTask.new(:rubocop) do |t|
end

PACKAGES.each do |package|
  namespace package.to_sym do
    Bundler::GemHelper.install_tasks dir: File.expand_path(package, __dir__)
  end
end

desc 'Release and publish all'
task release: PACKAGES.map {|ns| "#{ns}:release" }

task default: %i[spec rubocop]
