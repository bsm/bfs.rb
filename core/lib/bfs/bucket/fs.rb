require 'bfs'
require 'fileutils'
require 'pathname'

module BFS
  module Bucket
    # FS buckets are operating on the file system
    class FS < Abstract
      def initialize(root, opts={})
        super(opts.dup)

        @root = Pathname.new(root.to_s)
        @prefix = "#{@root.to_s.chomp('/')}/"
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern='**/*', _opts={})
        Enumerator.new do |y|
          Pathname.glob(@root.join(pattern)) do |pname|
            y << trim_prefix(pname.to_s) if pname.file?
          end
        end
      end

      # Info returns the info for a single file
      def info(path, _opts={})
        full = @root.join(norm_path(path))
        path = trim_prefix(full.to_s)
        BFS::FileInfo.new(path, full.size, full.mtime, nil, {})
      rescue Errno::ENOENT
        raise BFS::FileNotFound, path
      end

      # Creates a new file and opens it for writing
      #
      # @param [String] path The creation path.
      # @param [Hash] opts Additional options.
      # @option opts [String] :encoding Custom encoding.
      def create(path, opts={}, &block)
        full = @root.join(norm_path(path))
        FileUtils.mkdir_p(full.dirname.to_s)

        enc  = opts[:encoding] || @encoding
        temp = BFS::TempWriter.new(full, encoding: enc) {|t| FileUtils.mv t, full.to_s }
        return temp unless block

        begin
          yield temp
        ensure
          temp.close
        end
      end

      # Opens an existing file for reading
      #
      # @param [String] path The path to open.
      # @param [Hash] opts Additional options.
      # @option opts [String] :encoding Custom encoding.
      def open(path, opts={}, &block)
        path = norm_path(path)
        full = @root.join(path)
        full.open('rb', opts, &block)
      rescue Errno::ENOENT
        raise BFS::FileNotFound, path
      end

      # Deletes a file.
      #
      # @param [String] path The path to delete.
      def rm(path, _opts={})
        full = @root.join(norm_path(path))
        FileUtils.rm_f full.to_s
      end

      # Copies a file.
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def cp(src, dst, _opts={})
        full_src = @root.join(norm_path(src))
        full_dst = @root.join(norm_path(dst))
        FileUtils.mkdir_p full_dst.dirname.to_s
        FileUtils.cp full_src.to_s, full_dst.to_s
      rescue Errno::ENOENT
        raise BFS::FileNotFound, norm_path(src)
      end

      # Moves a file.
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def mv(src, dst, _opts={})
        full_src = @root.join(norm_path(src))
        full_dst = @root.join(norm_path(dst))
        FileUtils.mkdir_p full_dst.dirname.to_s
        FileUtils.mv full_src.to_s, full_dst.to_s
      rescue Errno::ENOENT
        raise BFS::FileNotFound, norm_path(src)
      end
    end
  end
end

BFS.register('file') do |url|
  parts = [url.host, url.path].compact
  BFS::Bucket::FS.new File.join(*parts)
end
