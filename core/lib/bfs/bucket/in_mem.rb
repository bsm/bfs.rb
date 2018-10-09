require 'bfs'
require 'stringio'

module BFS
  module Bucket
    # InMem buckets are useful for tests
    class InMem < Abstract
      Entry = Struct.new(:io, :mtime)

      def initialize
        @files = {}
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern='**/*', _opts={})
        @files.each_key.select do |key|
          File.fnmatch?(pattern, key, File::FNM_PATHNAME)
        end
      end

      # Info returns the file info
      def info(path, _opts={})
        path = norm_path(path)
        raise BFS::FileNotFound, path unless @files.key?(path)

        entry = @files[path]
        BFS::FileInfo.new(path, entry.io.size, entry.mtime)
      end

      # Creates a new file and opens it for writing
      def create(path, _opts={}, &block)
        io = StringIO.new
        @files[norm_path(path)] = Entry.new(io, Time.now)
        return io unless block

        begin
          yield(io)
        ensure
          io.close
        end
      end

      # Opens an existing file for reading
      def open(path, _opts={}, &block)
        path = norm_path(path)
        raise BFS::FileNotFound, path unless @files.key?(path)

        io = @files[path].io
        io.reopen(io.string)
        return io unless block

        begin
          yield(io)
        ensure
          io.close
        end
      end

      # Deletes a file.
      def rm(path, _opts={})
        @files.delete(norm_path(path))
      end
    end
  end
end
