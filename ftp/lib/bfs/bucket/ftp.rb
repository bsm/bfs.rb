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
        dir = pattern[%r{^[^\*\?\{\}\[\]]+/}]
        dir&.chomp!('/')

        Enumerator.new do |y|
          glob(dir) do |path|
            y << path if File.fnmatch?(pattern, path, File::FNM_PATHNAME)
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
        temp = BFS::TempWriter.new(path, encoding: encoding, perm: perm) do |t|
          mkdir_p File.dirname(path)
          @client.put(t, path)
        end
        return temp unless block

        begin
          yield temp
        ensure
          temp.close
        end
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

      def glob(dir, &block)
        @client.ls(dir || '.') do |e|
          entry = Net::FTP::List.parse(e)
          if entry.dir?
            subdir = [dir, entry.basename].compact.join('/')
            glob subdir, &block
          elsif entry.file?
            yield [dir, entry.basename].compact.join('/')
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

BFS.register('ftp', 'sftp') do |url, opts|
  BFS::Bucket::FTP.new url.host, **opts,
                       username: url.user ? CGI.unescape(url.user) : nil,
                       password: url.password ? CGI.unescape(url.password) : nil,
                       port: url.port,
                       ssl: opts.key?(:ssl) || url.scheme == 'sftp'
end
