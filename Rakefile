require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'bundler/gem_helper'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = '*/spec/**{,/*/**}/*_spec.rb'
end

RuboCop::RakeTask.new(:rubocop) do |t|
end

PACKAGES = Dir['*/*.gemspec'].map {|fn| File.dirname(fn) }.freeze

namespace :pkg do
  PACKAGES.each do |name|
    namespace name.to_sym do
      Bundler::GemHelper.install_tasks dir: File.expand_path(name, __dir__)
    end
  end
end

desc 'Release and publish all'
task release: PACKAGES.map {|name| "pkg:#{name}:release" }

task default: %i[spec rubocop]
