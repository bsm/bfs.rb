require 'bfs'
require 'google/cloud/storage'

module BFS
  module Bucket
    # GS buckets are operating on Google Cloud Storage
    class GS < Abstract
      attr_reader :name

      # Initializes a new GoogleCloudStorage bucket.
      #
      # @param [String] name the bucket name.
      # @param [Hash] opts options.
      # @option opts [String] :project_id project ID. Defaults to GCP_PROJECT env var.
      # @option opts [String, Hash, Google::Auth::Credentials] :credentials
      #   the path to the keyfile as a String, the contents of the keyfile as a Hash, or a Google::Auth::Credentials object.
      # @option opts [String] :prefix custom namespace within the bucket
      # @option opts [Integer] :retries number of times to retry requests. Default: 3.
      # @option opts [Integer] :timeout request timeout, in seconds.
      # @option opts [String] :acl set the default ACL.
      # @option opts [Google::Cloud::Storage] :client custom client.
      # @option opts [String] :encoding Custom encoding.
      def initialize(name, prefix: nil, acl: nil, client: nil, **opts)
        super(**opts)

        @prefix = prefix
        client ||= Google::Cloud::Storage.new(**opts)

        @name   = name.to_s
        @bucket = client.bucket(@name)
        @bucket.default_acl.send(:"#{acl}!") if @bucket.default_acl.respond_to?(:"#{acl}!")
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern = '**/*', **opts)
        prefix = pattern[%r{^[^*?\{\}\[\]]+/}]
        prefix = File.join(*[@prefix, prefix].compact) if @prefix
        opts   = opts.merge(prefix: prefix) if prefix

        Enumerator.new do |y|
          @bucket.files(**opts).all do |file|
            name = trim_prefix(file.name)
            y << name if File.fnmatch?(pattern, name, File::FNM_PATHNAME)
          end
        end
      end

      # Info returns the object info
      def info(path, **_opts)
        path = full_path(path)
        file = @bucket.file(path)
        raise BFS::FileNotFound, trim_prefix(path) unless file

        name = trim_prefix(file.name)
        BFS::FileInfo.new(path: name, size: file.size, mtime: file.updated_at.to_time, content_type: file.content_type, metadata: norm_meta(file.metadata))
      end

      # Creates a new file and opens it for writing
      def create(path, encoding: self.encoding, perm: self.perm, **opts, &block)
        opts[:metadata] = norm_meta(opts[:metadata])
        path = full_path(path)
        temp = BFS::TempWriter.new(path, encoding: encoding, perm: perm) do |t|
          File.open(t, encoding: encoding) do |file|
            @bucket.create_file(file, path, **opts)
          end
        end
        return temp unless block

        begin
          yield temp
        ensure
          temp.close
        end
      end

      # Opens an existing file for reading
      def open(path, encoding: self.encoding, tempdir: nil, **opts, &block)
        path = full_path(path)
        file = @bucket.file(path)
        raise BFS::FileNotFound, trim_prefix(path) unless file

        temp = Tempfile.new(File.basename(path), tempdir, encoding: encoding)
        temp.close
        file.download(temp.path, **opts)

        File.open(temp.path, encoding: encoding, &block)
      end

      # Deletes a file.
      def rm(path, **opts)
        path = full_path(path)
        file = @bucket.file(path)
        file&.delete(**opts)
      end

      # Copies a file.
      def cp(src, dst, **opts)
        src  = full_path(src)
        file = @bucket.file(src)
        raise BFS::FileNotFound, trim_prefix(src) unless file

        file.copy(full_path(dst), **opts)
      end
    end
  end
end

BFS.register('gs') do |url, opts, block|
  prefix = BFS.norm_path(opts.key?(:prefix) ? opts[:prefix] : url.path)
  prefix = nil if prefix.empty?
  opts   = opts.slice(:project_id, :credentials, :acl)
  extra  = {
    prefix: prefix,
    timeout: opts.key?(:timeout) ? opts[:timeout].to_i : nil,
    retries: opts.key?(:retries) ? opts[:retries].to_i : nil,
  }

  BFS::Bucket::GS.open url.host, **opts, **extra, &block
end
