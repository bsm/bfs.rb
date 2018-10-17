require 'bfs'
require 'cgi'
require 'fileutils'
require 'pathname'

module BFS
  module Bucket
    # FS buckets are operating on the file system
    class FS < Abstract
      def initialize(root, _opts={})
        @root = Pathname.new(root.to_s)
        @prefix = "#{@root}/"
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern='**/*', _opts={})
        Pathname.glob(@root.join(pattern)).select(&:file?).map do |name|
          name.to_s.sub(@prefix, '')
        end
      end

      # Info returns the info for a single file
      def info(path, _opts={})
        name = @root.join(norm_path(path))
        path = name.to_s.sub(@prefix, '')
        BFS::FileInfo.new(path, name.size, name.mtime)
      rescue Errno::ENOENT
        raise BFS::FileNotFound, path
      end

      # Creates a new file and opens it for writing
      def create(path, _opts={}, &block)
        name = @root.join(norm_path(path))
        FileUtils.mkdir_p(name.dirname.to_s)

        temp = BFS::TempWriter.new(name) {|t| FileUtils.mv t, name.to_s }
        return temp unless block

        begin
          yield temp
        ensure
          temp.close
        end
      end

      # Opens an existing file for reading
      def open(path, opts={}, &block)
        path = norm_path(path)
        name = @root.join(path)
        name.open('r', opts, &block)
      rescue Errno::ENOENT
        raise BFS::FileNotFound, path
      end

      # Deletes a file.
      def rm(path, _opts={})
        name = @root.join(norm_path(path))
        FileUtils.rm_f name.to_s
      end

      # Copies a file.
      def cp(src, dst, _opts={})
        src = norm_path(src)
        dst = norm_path(dst)
        FileUtils.cp @root.join(src).to_s, @root.join(dst).to_s
      rescue Errno::ENOENT
        raise BFS::FileNotFound, src
      end

      # Moves a file.
      def mv(src, dst, _opts={})
        src = norm_path(src)
        dst = norm_path(dst)
        FileUtils.mv @root.join(src).to_s, @root.join(dst).to_s
      rescue Errno::ENOENT
        raise BFS::FileNotFound, src
      end
    end
  end
end

BFS.register('file') do |url|
  params = CGI.parse(url.query.to_s)

  parts = [url.host, url.path].compact
  root  = case params.key?('scope') && params['scope'].first
          when 'root'
            '/'
          when 'dir'
            File.dirname(File.join(*parts))
          else
            File.join(*parts)
          end
  BFS::Bucket::FS.new root
end
