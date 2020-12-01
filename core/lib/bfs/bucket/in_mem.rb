require 'bfs'
require 'stringio'
require 'delegate'

module BFS
  module Bucket
    # InMem buckets are useful for tests
    class InMem < Abstract
      Entry = Struct.new(:io, :mtime, :content_type, :metadata)

      class Writer < DelegateClass(::StringIO)
        include BFS::Writer::Mixin

        def initialize(encoding:, &on_commit)
          @on_commit = on_commit

          sio = StringIO.new
          sio.set_encoding(encoding)
          super sio
        end

        alias close! close
        alias commit_ref __getobj__
      end

      def initialize(**opts)
        super(**opts.dup)
        @files = {}
      end

      # Reset bucket and clear all files.
      def clear
        @files.clear
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern = '**/*', **_opts)
        Enumerator.new do |y|
          @files.each_key do |key|
            y << key if File.fnmatch?(pattern, key, File::FNM_PATHNAME)
          end
        end
      end

      # Info returns the file info
      def info(path, **_opts)
        path = norm_path(path)
        raise BFS::FileNotFound, path unless @files.key?(path)

        entry = @files[path]
        BFS::FileInfo.new(path: path, size: entry.io.size, mtime: entry.mtime, content_type: entry.content_type, metadata: entry.metadata)
      end

      # Creates a new file and opens it for writing.
      #
      # @param [String] path The creation path.
      # @param [Hash] opts Additional options.
      # @option opts [String] :encoding Custom encoding.
      # @option opts [String] :content_type Custom content type.
      # @option opts [Hash] :metadata Metadata key-value pairs.
      def create(path, encoding: self.encoding, content_type: nil, metadata: nil, **_opts, &block)
        Writer.new(encoding: encoding) do |wio|
          @files[norm_path(path)] = Entry.new(wio, Time.now, content_type, norm_meta(metadata))
        end.perform(&block)
      end

      # Opens an existing file for reading
      def open(path, **_opts, &block)
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
      def rm(path, **_opts)
        @files.delete(norm_path(path))
      end
    end
  end
end
