require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = '*/spec/**{,/*/**}/*_spec.rb'
end

RuboCop::RakeTask.new(:rubocop) do |t|
end

task default: %i[spec rubocop]
