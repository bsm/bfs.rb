ENV['AWS_ACCESS_KEY_ID'] ||= 'bogus'
ENV['AWS_SECRET_ACCESS_KEY'] ||= 'bogusbogusbogusbogusbogus'

require 'rspec'
require 'bfs'
require 'bfs/gs'
require 'bfs/s3'
require_relative './support/shared.rb'
