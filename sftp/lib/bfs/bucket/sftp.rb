require 'bfs'
require 'net/sftp'

module BFS
  module Bucket
    # SFTP buckets are operating on SFTP connections.
    class SFTP < Abstract
      StatusCodes = Net::SFTP::Constants::StatusCodes

      # Initializes a new bucket
      # @param [String] host the host name
      # @param [Hash] opts options
      # @option opts [Integer] :port custom port. Default: 22.
      # @option opts [String] :user user name for login.
      # @option opts [String] :password password for login.
      # @option opts [String] :prefix optional prefix.
      # @option opts [Boolean] :compression use compression.
      # @option opts [Boolean] :keepalive use keepalive.
      # @option opts [Integer] :keepalive_interval interval if keepalive enabled. Default: 300.
      # @option opts [Array<String>] :keys an array of file names of private keys to use for publickey and hostbased authentication.
      # @option opts [Boolean|Symbol] :verify_host_key specifying how strict host-key verification should be, either false, true, :very, or :secure.
      def initialize(host, prefix: nil, **opts)
        super(**opts)

        @prefix  = prefix
        @session = Net::SSH.start(host, nil, **opts.slice(*Net::SSH::VALID_OPTIONS), non_interactive: true)

        if @prefix # rubocop:disable Style/GuardClause
          @prefix = "#{norm_path(@prefix)}/"
          mkdir_p @prefix
        end
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern = '**/*', **_opts)
        Enumerator.new do |acc|
          walk(pattern) {|path, _| acc << path }
        end
      end

      # Iterates over the contents of a bucket using a glob pattern
      def glob(pattern = '**/*', **_opts)
        Enumerator.new do |acc|
          walk(pattern) do |path, attrs|
            acc << file_info(path, attrs)
          end
        end
      end

      # Info returns the object info
      def info(path, **_opts)
        full = full_path(path)
        path = norm_path(path)
        attrs = @session.sftp.stat!(full)
        raise BFS::FileNotFound, path unless attrs.file?

        file_info path, attrs
      rescue Net::SFTP::StatusException => e
        raise BFS::FileNotFound, path if e.code == StatusCodes::FX_NO_SUCH_FILE

        raise
      end

      # Creates a new file and opens it for writing
      # @option opts [String|Encoding] :encoding Custom file encoding.
      # @option opts [Integer] :perm Custom file permission, default: 0600.
      def create(path, encoding: self.encoding, perm: self.perm, **opts, &block)
        full = full_path(path)

        opts[:preserve] = true if perm && !opts.key?(:preserve)
        BFS::Writer.new(path, encoding: encoding, perm: perm) do |temp_path|
          mkdir_p File.dirname(full)
          @session.sftp.upload!(temp_path, full, **opts)
        end.perform(&block)
      end

      # Opens an existing file for reading
      def open(path, encoding: self.encoding, tempdir: nil, **_opts, &block)
        full = full_path(path)
        temp = Tempfile.new(File.basename(path), tempdir, encoding: encoding)
        temp.close

        @session.sftp.download!(full, temp.path)
        File.open(temp.path, encoding: encoding, &block)
      rescue Net::SFTP::StatusException => e
        raise BFS::FileNotFound, path if e.code == StatusCodes::FX_NO_SUCH_FILE

        raise
      end

      # Deletes a file.
      def rm(path, **_opts)
        full = full_path(path)
        @session.sftp.remove!(full)
      rescue Net::SFTP::StatusException => e
        raise unless e.code == StatusCodes::FX_NO_SUCH_FILE
      end

      # Closes the underlying connection
      def close
        @session.close unless @session.closed?
      end

      private

      def file_info(path, attrs)
        BFS::FileInfo.new(path: path, size: attrs.size.to_i, mtime: Time.at(attrs.mtime.to_i), mode: BFS.norm_mode(attrs.permissions))
      end

      def walk(pattern)
        @session.sftp.dir.glob(@prefix || '/', pattern) do |ent|
          next unless ent.file?

          path = norm_path(ent.name)
          yield(path, ent.attributes)
        end
      end

      def mkdir_p(path)
        parts = path.split('/').reject(&:empty?)
        cmds  = (0...parts.size).map do |i|
          @session.sftp.mkdir parts[0..i].join('/')
        end
        cmds.each do |req|
          req.wait
          next if req.response.code <= StatusCodes::FX_FAILURE

          raise Net::SFTP::StatusException, req.response
        end
      end
    end
  end
end

BFS.register('sftp') do |url, opts, block|
  prefix = BFS.norm_path(opts[:prefix] || url.path)
  opts[:prefix] = prefix unless prefix.empty?
  opts[:user] ||= CGI.unescape(url.user) if url.user
  opts[:password] ||= CGI.unescape(url.password) if url.password
  opts[:port] ||= url.port if url.port

  BFS::Bucket::SFTP.open(url.host, **opts, &block)
end
