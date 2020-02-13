require 'uri'
require 'cgi'

module BFS
  class FileInfo < Hash
    def initialize(**attrs)
      update(size: 0, mtime: Time.at(0), mode: 0, metadata: {})
      update(attrs)
    end

    def path
      fetch(:path, nil)
    end

    def size
      fetch(:size, 0)
    end

    def content_type
      fetch(:content_type, nil)
    end

    def mtime
      fetch(:mtime, Time.at(0))
    end

    def mode
      fetch(:mode, 0)
    end

    def metadata
      fetch(:metadata, {})
    end
  end

  def self.register(*schemes, &resolver)
    @registry ||= {}
    schemes.each do |scheme|
      @registry[scheme] = resolver
    end
  end

  def self.resolve(url)
    url = url.is_a?(::URI) ? url.dup : URI.parse(url)
    rsl = @registry[url.scheme]
    raise ArgumentError, "Unable to resolve #{url}, scheme #{url.scheme} is not registered" unless rsl

    opts = {}
    CGI.parse(url.query.to_s).each do |key, values|
      opts[key.to_sym] = values.first
    end
    rsl.call(url, opts)
  end

  def self.norm_path(path)
    path = path.to_s.dup
    path.gsub!(File::SEPARATOR, '/')
    path.sub!(%r{^/+}, '')
    path.sub!(%r{/+$}, '')
    path
  end

  def self.norm_mode(mode)
    mode = mode.to_i(8) if mode.is_a?(String)
    mode & 0o000777
  end
end

require 'bfs/helpers'
require 'bfs/bucket'
require 'bfs/errors'
require 'bfs/blob'
