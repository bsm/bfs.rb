require 'bfs'
require 'net/ftp/list'
require 'cgi'

module BFS
  module Bucket
    # FTP buckets are operating on ftp servers
    class FTP < Abstract

      # Initializes a new bucket
      # @param [String] host the host name
      # @param [Hash] opts options
      # @option opts [Integer] :port custom port. Default: 21.
      # @option opts [Boolean] :ssl will attempt to use SSL.
      # @option opts [String] :username user name for login.
      # @option opts [String] :password password for login.
      # @option opts [String] :passive connect in passive mode. Default: true.
      # @option opts [String] :prefix optional prefix.
      def initialize(host, opts={})
        opts = opts.dup
        opts.keys.each do |key|
          val = opts.delete(key)
          opts[key.to_sym] = val unless val.nil?
        end
        super(opts)

        prefix  = opts.delete(:prefix)
        @client = Net::FTP.new(host, opts)
        @client.binary = true
        return unless prefix

        prefix = norm_path(prefix)
        mkdir_p(prefix)
        @client.chdir(prefix)
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern='**/*', _opts={})
        root = pattern[%r{^[^\*\?\{\}\[\]]+/}]
        root.chomp!('/') if root
        Enumerator.new do |y|
          glob(root) do |path|
            y << path if File.fnmatch?(pattern, path, File::FNM_PATHNAME)
          end
        end
      end

      # Info returns the object info
      def info(path, _opts={})
        path = norm_path(path)
        BFS::FileInfo.new(path, @client.size(path), @client.mtime(path))
      rescue Net::FTPPermError
        raise BFS::FileNotFound, path
      end

      # Creates a new file and opens it for writing
      def create(path, opts={}, &block)
        path = norm_path(path)
        enc  = opts.delete(:encoding) || @encoding
        temp = BFS::TempWriter.new(path, encoding: enc) do |t|
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
      def open(path, opts={}, &block)
        path = norm_path(path)
        enc  = opts.delete(:encoding) || @encoding
        temp = Tempfile.new(File.basename(path), encoding: enc)
        temp.close

        @client.get(path, temp.path)
        File.open(temp.path, encoding: enc, &block)
      rescue Net::FTPPermError
        raise BFS::FileNotFound, path
      end

      # Deletes a file.
      def rm(path, _opts={})
        path = norm_path(path)
        @client.delete(path)
      rescue Net::FTPPermError # rubocop:disable Lint/HandleExceptions
      end

      # Closes the underlying connection
      def close
        @client.close
      end

      private

      def glob(root, &block)
        @client.ls [root, '*'].compact.join('/') do |e|
          entry = Net::FTP::List.parse(e)
          if entry.dir?
            newroot = [root, entry.basename].compact.join('/')
            glob newroot, &block
          elsif entry.file?
            yield [root, entry.basename].compact.join('/')
          end
        end
      end

      def mkdir_p(path)
        parts = path.split('/').reject(&:empty?)
        (0...parts.size).each do |i|
          begin
            @client.mkdir parts[0..i].join('/')
          rescue Net::FTPPermError # rubocop:disable Lint/HandleExceptions
          end
        end
      end
    end
  end
end

BFS.register('ftp', 'sftp') do |url|
  params = CGI.parse(url.query.to_s)

  BFS::Bucket::FTP.new url.host,
    username: url.user,
    password: url.password,
    port: url.port,
    ssl: params.key?('ssl') || url.scheme == 'sftp',
    prefix: params.key?('prefix') ? params['prefix'].first : nil
end
