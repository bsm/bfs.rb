require 'bfs'

module BFS
  module Bucket
    class Abstract
      attr_reader :encoding, :perm

      # Behaves like new, but accepts an optional block.
      # If a block is given, buckets are automatically closed after the block is yielded.
      def self.open(*args, **opts)
        bucket = new(*args, **opts)
        begin
          yield bucket
        ensure
          bucket.close
        end if block_given?
        bucket
      end

      # Initializes a new bucket
      # @param [Hash] opts options
      # @option opts [String] :encoding Custom encoding. Default: Encoding.default_external.
      # @option opts [Integer] :perm optional file permissions. Default: 0600.
      def initialize(encoding: Encoding.default_external, perm: nil, **_opts)
        @encoding = encoding

        case perm
        when Integer
          @perm = perm
        when String
          @perm = perm.to_i(8)
        end

        BFS.defer(self, :close)
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(_pattern = '**', **_opts)
        raise 'not implemented'
      end

      # Info returns the info for a single file
      def info(_path, **_opts)
        raise 'not implemented'
      end

      # Creates a new file and opens it for writing
      def create(_path, **_opts)
        raise 'not implemented'
      end

      # Opens an existing file for reading
      # May raise BFS::FileNotFound
      def open(_path, **_opts)
        raise 'not implemented'
      end

      # Deletes a file.
      def rm(_path, **_opts)
        raise 'not implemented'
      end

      # Shortcut method to read the contents of a file into memory
      #
      # @param [String] path The path to read from.
      # @param [Hash] opts Additional options, see #open.
      def read(path, **opts)
        self.open(path, **opts, &:read)
      end

      # Shortcut method to write data to path
      #
      # @param [String] path The path to write to.
      # @param [String] data The data to write.
      # @param [Hash] opts Additional options, see #create.
      def write(path, data, **opts)
        create(path, **opts) {|f| f.write data }
      end

      # Copies src to dst
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def cp(src, dst, **opts)
        self.open(src, **opts) do |r|
          create(dst, **opts) do |w|
            IO.copy_stream(r, w)
          end
        end
      end

      # Moves src to dst
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def mv(src, dst, **_opts)
        cp(src, dst)
        rm(src)
      end

      # Closes the underlying connection
      def close; end

      protected

      def norm_meta(meta)
        norm = {}
        meta.each do |key, value|
          nkey = key.to_s.downcase.split(/-/).map(&:capitalize).join('-')
          norm[nkey] = value
        end if meta.is_a?(Hash)
        norm
      end

      def norm_path(path)
        BFS.norm_path(path) if path
      end

      def full_path(path)
        path = norm_path(path)
        path = File.join(@prefix, path) if @prefix
        path
      end

      def trim_prefix(path)
        path.slice!(0, @prefix.size) if @prefix && path.slice(0, @prefix.size) == @prefix
        path
      end
    end
  end
end
