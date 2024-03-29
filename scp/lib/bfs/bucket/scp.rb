require 'bfs'
require 'net/scp'
require 'shellwords'

module BFS
  module Bucket
    # SCP buckets are operating on SCP/SSH connections.
    class SCP < Abstract
      class CommandError < RuntimeError
        attr_reader :status

        def initialize(cmd, status, extra = nil)
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
      # @option opts [Symbol] :verify_host_key host-key verification should be, either :never, :accept_new_or_local_tunnel, :accept_new, or :always.
      def initialize(host, prefix: nil, **opts)
        super(**opts)

        @prefix = prefix
        @client = Net::SCP.start(host, nil, **opts.slice(*Net::SSH::VALID_OPTIONS), non_interactive: true)

        if @prefix # rubocop:disable Style/GuardClause
          @prefix = "#{norm_path(@prefix)}/"
          mkdir_p abs_path(@prefix)
        end
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern = '**/*', **_opts)
        Enumerator.new do |acc|
          walk(pattern) {|path| acc << path }
        end
      end

      # Iterates over the contents of a bucket using a glob pattern
      def glob(pattern = '**/*', **_opts)
        Enumerator.new do |acc|
          walk(pattern, with_stat: true) {|info| acc << info }
        end
      end

      # Info returns the object info
      def info(path, **_opts)
        full = full_path(path)
        path = norm_path(path)
        out  = sh! %(stat -c '%F;%s;%Z;%a' #{Shellwords.escape full})

        type, size, epoch, mode = out.strip.split(';', 4)
        raise BFS::FileNotFound, path unless type.include?('file')

        BFS::FileInfo.new(path: path, size: size.to_i, mtime: Time.at(epoch.to_i), mode: BFS.norm_mode(mode))
      rescue CommandError => e
        e.status == 1 ? raise(BFS::FileNotFound, path) : raise
      end

      # Creates a new file and opens it for writing
      # @option opts [String|Encoding] :encoding Custom file encoding.
      # @option opts [Integer] :perm Custom file permission, default: 0600.
      def create(path, encoding: self.encoding, perm: self.perm, **opts, &block)
        full = full_path(path)

        opts[:preserve] = true if perm && !opts.key?(:preserve)
        BFS::Writer.new(path, encoding: encoding, perm: perm) do |temp_path|
          mkdir_p File.dirname(full)
          @client.upload!(temp_path, full, **opts)
        end.perform(&block)
      end

      # Opens an existing file for reading
      def open(path, encoding: self.encoding, tempdir: nil, **_opts, &block)
        full = full_path(path)
        temp = Tempfile.new(File.basename(path), tempdir, encoding: encoding)
        temp.close

        @client.download!(full, temp.path)
        File.open(temp.path, encoding: encoding, &block)
      rescue Net::SCP::Error
        raise BFS::FileNotFound, path
      end

      # Deletes a file.
      def rm(path, **_opts)
        path = full_path(path)
        sh! %(rm -f #{Shellwords.escape(path)})
      end

      # Copies src to dst
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def cp(src, dst, **_opts)
        full_src = full_path(src)
        full_dst = full_path(dst)

        mkdir_p File.dirname(full_dst)
        sh! %(cp -a -f #{Shellwords.escape(full_src)} #{Shellwords.escape(full_dst)})
      rescue CommandError => e
        e.status == 1 ? raise(BFS::FileNotFound, src) : raise
      end

      # Moves src to dst
      #
      # @param [String] src The source path.
      # @param [String] dst The destination path.
      def mv(src, dst, **_opts)
        full_src = full_path(src)
        full_dst = full_path(dst)

        mkdir_p File.dirname(full_dst)
        sh! %(mv -f #{Shellwords.escape(full_src)} #{Shellwords.escape(full_dst)})
      rescue CommandError => e
        e.status == 1 ? raise(BFS::FileNotFound, src) : raise
      end

      # Closes the underlying connection
      def close
        @client.session.close unless @client.session.closed?
      end

      private

      def abs_path(path)
        path = "/#{path}" unless path.start_with?('~/', './')
        path
      end

      def full_path(*)
        abs_path(super)
      end

      def walk(pattern, with_stat: false)
        prefix  = @prefix ? abs_path(@prefix) : '/'
        command = %(find #{Shellwords.escape(prefix)} -type f)
        command << %( -exec stat -c '%s;%Z;%a;%n' {} \\;) if with_stat

        sh!(command) do |out|
          out.each_line do |line|
            line.strip!

            if with_stat
              size, epoch, mode, path = out.strip.split(';', 4)
              path = trim_prefix(norm_path(path))
              next unless File.fnmatch?(pattern, path, File::FNM_PATHNAME)

              info = BFS::FileInfo.new(path: path, size: size.to_i, mtime: Time.at(epoch.to_i), mode: BFS.norm_mode(mode))
              yield info
            else
              path = trim_prefix(norm_path(line))
              yield path if File.fnmatch?(pattern, path, File::FNM_PATHNAME)
            end
          end
        end
      end

      def mkdir_p(path)
        sh! %(mkdir -p #{Shellwords.escape(path)})
      end

      def sh!(command) # rubocop:disable Metrics/MethodLength
        stdout = ''
        stderr = nil
        status = 0

        @client.session.open_channel do |ch|
          ch.exec(command) do |_, _success|
            ch.on_data do |_, data|
              stdout << data

              if block_given?
                pos = stdout.rindex("\n")
                yield stdout.slice!(0..pos) if pos
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

        if block_given? && stdout.length.positive?
          yield stdout
          stdout.clear
        end

        @client.session.loop
        raise CommandError.new(command, status, stderr) unless status.zero?

        stdout
      end
    end
  end
end

BFS.register('scp', 'ssh') do |url, opts, block|
  prefix = BFS.norm_path(opts[:prefix] || url.path)
  opts[:prefix] = prefix unless prefix.empty?
  opts[:user] ||= CGI.unescape(url.user) if url.user
  opts[:password] ||= CGI.unescape(url.password) if url.password
  opts[:port] ||= url.port if url.port
  opts[:verify_host_key] = opts[:verify_host_key].to_sym if opts[:verify_host_key]

  BFS::Bucket::SCP.open(url.host, **opts, &block)
end
