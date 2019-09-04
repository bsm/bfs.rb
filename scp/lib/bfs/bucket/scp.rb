require 'bfs'
require 'net/scp'
require 'cgi'
require 'shellwords'

module BFS
  module Bucket
    # SCP buckets are operating on SCP/SSH connections.
    class SCP < Abstract
      class CommandError < RuntimeError
        attr_reader :status

        def initialize(cmd, status, extra=nil)
          @status = status
          super ["Command '#{cmd}' exited with status #{status}", extra].join(': ')
        end
      end

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
      def initialize(host, opts={})
        opts = opts.dup
        opts.keys.each do |key|
          val = opts.delete(key)
          opts[key.to_sym] = val unless val.nil?
        end
        super(opts)

        @prefix = opts.delete(:prefix)
        @client = Net::SCP.start(host, nil, opts)

        if @prefix # rubocop:disable Style/GuardClause
          @prefix = norm_path(@prefix) + '/'
          mkdir_p(@prefix)
        end
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern='**/*', _opts={})
        prefix = @prefix || '.'
        Enumerator.new do |y|
          sh! 'find', prefix, '-type', 'f' do |out|
            out.each_line do |line|
              path = trim_prefix(line.strip)
              y << path if File.fnmatch?(pattern, path, File::FNM_PATHNAME)
            end
          end
        end
      end

      # Info returns the object info
      def info(path, _opts={})
        full = full_path(path)
        path = norm_path(path)
        out  = sh! 'stat', '-c', '%s;%Z', full

        size, epoch = out.strip.split(';', 2).map(&:to_i)
        BFS::FileInfo.new(path, size, Time.at(epoch))
      rescue CommandError => e
        e.status == 1 ? raise(BFS::FileNotFound, path) : raise
      end

      # Creates a new file and opens it for writing
      def create(path, opts={}, &block)
        full = full_path(path)
        enc  = opts.delete(:encoding) || @encoding
        temp = BFS::TempWriter.new(path, encoding: enc) do |temp_path|
          mkdir_p File.dirname(full)
          @client.upload!(temp_path, full)
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
        full = full_path(path)
        enc  = opts.delete(:encoding) || @encoding
        temp = Tempfile.new(File.basename(path), encoding: enc)
        temp.close

        @client.download!(full, temp.path)
        File.open(temp.path, encoding: enc, &block)
      rescue Net::SCP::Error
        raise BFS::FileNotFound, path
      end

      # Deletes a file.
      def rm(path, _opts={})
        path = full_path(path)
        sh! 'rm', '-f', path
      end

      # Copies src to dst
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def cp(src, dst, _opts={})
        full_src = full_path(src)
        full_dst = full_path(dst)

        mkdir_p File.dirname(full_dst)
        sh! 'cp', '-a', '-f', full_src, full_dst
      rescue CommandError => e
        e.status == 1 ? raise(BFS::FileNotFound, src) : raise
      end

      # Moves src to dst
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def mv(src, dst, _opts={})
        full_src = full_path(src)
        full_dst = full_path(dst)

        mkdir_p File.dirname(full_dst)
        sh! 'mv', '-f', full_src, full_dst
      rescue CommandError => e
        e.status == 1 ? raise(BFS::FileNotFound, src) : raise
      end

      # Closes the underlying connection
      def close
        @client.session.close unless @client.session.closed?
      end

      private

      def mkdir_p(path)
        sh! 'mkdir', '-p', path
      end

      def sh!(*cmd) # rubocop:disable Metrics/MethodLength
        stdout = ''
        stderr = nil
        status = 0
        cmdstr = cmd.map {|x| Shellwords.escape(x) }.join(' ')

        @client.session.open_channel do |ch|
          ch.exec(cmdstr) do |_, _success|
            ch.on_data do |_, data|
              if block_given?
                yield data
              else
                stdout += data
              end
            end
            ch.on_extended_data do |_, _, data|
              stderr = data
            end
            ch.on_request('exit-status') do |_, buf|
              status = buf.read_long
            end
          end
        end
        @client.session.loop
        raise CommandError.new(cmdstr, status, stderr) unless status.zero?

        stdout
      end
    end
  end
end

BFS.register('scp', 'ssh') do |url|
  opts = {}
  CGI.parse(url.query.to_s).each do |key, values|
    opts[key.to_sym] = values.first
  end
  opts[:user] ||= CGI.unescape(url.user) if url.user
  opts[:password] ||= CGI.unescape(url.password) if url.password
  opts[:port] ||= url.port if url.port

  BFS::Bucket::SCP.new url.host, opts
end