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
      scheme = scheme.to_s
      raise(ArgumentError, "scheme #{scheme} is already registered") if @registry.key?(scheme)

      @registry[scheme] = resolver
    end
  end

  def self.unregister(*schemes)
    @registry ||= {}
    schemes.each do |scheme|
      scheme = scheme.to_s
      raise(ArgumentError, "scheme #{scheme} is not registered") unless @registry.key?(scheme)

      @registry.delete(scheme)
    end
  end

  def self.resolve(url, &block)
    url = url.is_a?(::URI) ? url.dup : URI.parse(url)
    rsl = @registry[url.scheme]
    raise ArgumentError, "Unable to resolve #{url}, scheme #{url.scheme} is not registered" unless rsl

    opts = {}
    CGI.parse(url.query.to_s).each do |key, values|
      opts[key.to_sym] = values.first
    end
    rsl.call(url, opts, block)
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

  def self.defer(obj, method)
    owner = Process.pid
    ObjectSpace.define_finalizer(obj, ->(*) { obj.send(method) if Process.pid == owner })
  end
end

require 'bfs/helpers'
require 'bfs/bucket'
require 'bfs/errors'
require 'bfs/blob'
