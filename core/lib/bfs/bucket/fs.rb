require 'bfs'
require 'fileutils'
require 'pathname'

module BFS
  module Bucket
    # FS buckets are operating on the file system
    class FS < Abstract
      def initialize(root, **opts)
        super(**opts.dup)

        @root = Pathname.new(root.to_s)
        @prefix = "#{@root.to_s.chomp('/')}/"
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern = '**/*', **_opts)
        Enumerator.new do |acc|
          walk(pattern) do |path, _|
            acc << path
          end
        end
      end

      # Iterates over the contents of a bucket using a glob pattern
      def glob(pattern = '**/*', **_opts)
        Enumerator.new do |acc|
          walk(pattern) do |path, stat|
            acc << file_info(path, stat)
          end
        end
      end

      # Info returns the info for a single file
      def info(path, **_opts)
        norm = norm_path(path)
        pn   = @root.join(norm)
        stat = pn.stat
        raise BFS::FileNotFound, path unless stat.file?

        file_info(norm, stat)
      rescue Errno::ENOENT
        raise BFS::FileNotFound, path
      end

      # Creates a new file and opens it for writing
      #
      # @param [String] path The creation path.
      # @param [Hash] opts Additional options.
      # @option opts [String] :encoding Custom encoding.
      # @option opts [Integer] :perm Custom file permission, default: 0600.
      def create(path, encoding: self.encoding, perm: self.perm, **_opts, &block)
        full = @root.join(norm_path(path))
        FileUtils.mkdir_p(full.dirname.to_s)

        BFS::Writer.new(full, encoding: encoding, perm: perm) do |temp|
          FileUtils.mv temp, full.to_s
        end.perform(&block)
      end

      # Opens an existing file for reading
      #
      # @param [String] path The path to open.
      # @param [Hash] opts Additional options.
      # @option opts [String] :encoding Custom encoding.
      def open(path, **opts, &block)
        path = norm_path(path)
        full = @root.join(path)
        full.open(**opts, &block)
      rescue Errno::ENOENT
        raise BFS::FileNotFound, path
      end

      # Deletes a file.
      #
      # @param [String] path The path to delete.
      def rm(path, **_opts)
        full = @root.join(norm_path(path))
        FileUtils.rm_f full.to_s
      end

      # Copies a file.
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def cp(src, dst, **_opts)
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
      def mv(src, dst, **_opts)
        full_src = @root.join(norm_path(src))
        full_dst = @root.join(norm_path(dst))
        FileUtils.mkdir_p full_dst.dirname.to_s
        FileUtils.mv full_src.to_s, full_dst.to_s
      rescue Errno::ENOENT
        raise BFS::FileNotFound, norm_path(src)
      end

      private

      def walk(pattern)
        Pathname.glob(@root.join(pattern)) do |pn|
          stat = pn.stat
          yield(trim_prefix(pn.to_s), stat) if stat.file?
        end
      end

      def file_info(path, stat)
        BFS::FileInfo.new(path: path, size: stat.size, mtime: stat.mtime, mode: BFS.norm_mode(stat.mode))
      end
    end
  end
end

BFS.register('file') do |url, opts, block|
  parts = [url.host, url.path].compact
  BFS::Bucket::FS.open(File.join(*parts), **opts, &block)
end
