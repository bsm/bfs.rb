require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'bundler/gem_helper'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = '*/spec/**{,/*/**}/*_spec.rb'
end

RuboCop::RakeTask.new(:rubocop) do |t|
end

namespace :core do
  Bundler::GemHelper.install_tasks dir: File.expand_path('core', __dir__)
end

namespace :s3 do
  Bundler::GemHelper.install_tasks dir: File.expand_path('s3', __dir__)
end


task default: %i[spec rubocop]
