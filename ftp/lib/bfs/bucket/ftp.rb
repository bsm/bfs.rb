require 'bfs'
require 'net/ftp/list'

module BFS
  module Bucket
    # FTP buckets are operating on ftp servers
    class FTP < Abstract
      attr_reader :perm

      # Initializes a new bucket
      # @param [String] host the host name
      # @param [Hash] opts options
      # @option opts [Integer] :port custom port. Default: 21.
      # @option opts [Boolean] :ssl will attempt to use SSL.
      # @option opts [String] :username user name for login.
      # @option opts [String] :password password for login.
      # @option opts [String] :passive connect in passive mode. Default: true.
      # @option opts [String] :prefix optional prefix.
      def initialize(host, prefix: nil, **opts)
        super(**opts)

        @client = Net::FTP.new(host, **opts)
        @client.binary = true

        if prefix # rubocop:disable Style/GuardClause
          prefix = norm_path(prefix)
          mkdir_p(prefix)
          @client.chdir(prefix)
        end
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern = '**/*', **_opts)
        Enumerator.new do |y|
          walk(pattern) do |path, _|
            y << path if File.fnmatch?(pattern, path, File::FNM_PATHNAME)
          end
        end
      end

      # Iterates over the contents of a bucket using a glob pattern
      def glob(pattern = '**/*', **_opts)
        Enumerator.new do |y|
          walk(pattern) do |path, entry|
            y << file_info(path, entry) if File.fnmatch?(pattern, path, File::FNM_PATHNAME)
          end
        end
      end

      # Info returns the object info
      def info(path, **_opts)
        path = norm_path(path)
        BFS::FileInfo.new(path: path, size: @client.size(path), mtime: @client.mtime(path))
      rescue Net::FTPPermError
        raise BFS::FileNotFound, path
      end

      # Creates a new file and opens it for writing
      def create(path, encoding: self.encoding, perm: self.perm, **_opts, &block)
        path = norm_path(path)
        BFS::Writer.new(path, encoding: encoding, perm: perm) do |t|
          mkdir_p File.dirname(path)
          @client.put(t, path)
        end.perform(&block)
      end

      # Opens an existing file for reading
      def open(path, encoding: self.encoding, perm: self.perm, tempdir: nil, **_opts, &block)
        path = norm_path(path)
        temp = Tempfile.new(File.basename(path), tempdir, encoding: encoding, perm: perm)
        temp.close

        @client.get(path, temp.path)
        File.open(temp.path, encoding: encoding, &block)
      rescue Net::FTPPermError
        raise BFS::FileNotFound, path
      end

      # Deletes a file.
      def rm(path, **_opts)
        path = norm_path(path)
        @client.delete(path)
      rescue Net::FTPPermError # rubocop:disable Lint/SuppressedException
      end

      # Closes the underlying connection
      def close
        @client.close
      end

      private

      def file_info(path, entry)
        BFS::FileInfo.new(path: path, size: entry.filesize, mtime: entry.mtime)
      end

      def walk(pattern, &block)
        dir = pattern[%r{^[^*?\{\}\[\]]+/}]
        dir&.chomp!('/')
        walk_r(dir, &block)
      end

      def walk_r(dir, &block)
        entries = @client.list(dir || '.')
        entries.each do |ent|
          entry = Net::FTP::List.parse(ent)
          if entry.dir?
            subdir = [dir, entry.basename].compact.join('/')
            walk_r(subdir, &block)
          elsif entry.file?
            path = [dir, entry.basename].compact.join('/')
            yield(path, entry)
          end
        end
      end

      def mkdir_p(path)
        parts = path.split('/').reject(&:empty?)
        (0...parts.size).each do |i|
          @client.mkdir parts[0..i].join('/')
        rescue Net::FTPPermError # rubocop:disable Lint/SuppressedException
        end
      end
    end
  end
end

BFS.register('ftp') do |url, opts, block|
  prefix = BFS.norm_path(opts[:prefix] || url.path)
  opts[:prefix] = prefix unless prefix.empty?

  extra = {
    username: url.user ? CGI.unescape(url.user) : nil,
    password: url.password ? CGI.unescape(url.password) : nil,
    port: url.port,
    ssl: opts.key?(:ssl),
  }
  BFS::Bucket::FTP.open url.host, **opts, **extra, &block
end
