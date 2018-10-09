require 'uri'

module BFS
  FileInfo = Struct.new(:path, :size, :mtime)

  def self.register(scheme, &resolver)
    @registry ||= {}
    @registry[scheme] = resolver
  end

  def self.resolve(url)
    url = URI.parse(url) unless url.is_a?(::URI)
    rsl = @registry[url.scheme]
    raise ArgumentError, "Unable to resolve #{url}, scheme #{url.scheme} is not registered" unless rsl

    rsl.call(url)
  end
end

require 'bfs/helpers'
require 'bfs/bucket'
require 'bfs/errors'
