require 'bfs'
require 'aws-sdk-s3'

module BFS
  module Bucket
    # S3 buckets are operating on s3
    class S3 < Abstract
      attr_reader :name, :sse, :acl, :storage_class

      # Initializes a new S3 bucket
      # @param [String] name the bucket name
      # @param [Hash] opts options
      # @option opts [String] :region default region
      # @option opts [String] :prefix custom namespace within the bucket
      # @option opts [String] :sse default server-side-encryption setting
      # @option opts [Aws::Credentials] :credentials credentials object
      # @option opts [String] :access_key_id custom AWS access key ID
      # @option opts [String] :secret_access_key custom AWS secret access key
      # @option opts [String] :profile_name custom AWS profile name (for shared credentials)
      # @option opts [Symbol] :acl canned ACL
      # @option opts [String] :storage_class storage class
      # @option opts [Aws::S3::Client] :client custom client, uses default_client by default
      def initialize(name, **opts)
        super(**opts)

        @name = name
        @sse = opts[:sse] || opts[:server_side_encryption]
        @prefix = opts[:prefix]
        @acl = opts[:acl].to_sym if opts[:acl]
        @storage_class = opts[:storage_class]
        @client = opts[:client] || init_client(**opts)
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern = '**/*', **opts)
        prefix = pattern[%r{^[^*?\{\}\[\]]+/}]
        prefix = File.join(*[@prefix, prefix].compact) if @prefix

        opts = opts.merge(bucket: name, prefix: @prefix)
        opts[:prefix] = prefix if prefix

        next_token = nil
        Enumerator.new do |y|
          loop do
            resp = @client.list_objects_v2 opts.merge(continuation_token: next_token)
            resp.contents.each do |obj|
              name = trim_prefix(obj.key)
              y << name if File.fnmatch?(pattern, name, File::FNM_PATHNAME)
            end
            next_token = resp.next_continuation_token.to_s
            break if next_token.empty?
          end
        end
      end

      # Info returns the object info
      def info(path, **opts)
        path = norm_path(path)
        opts = opts.merge(bucket: name, key: full_path(path))
        info = @client.head_object(**opts)
        raise BFS::FileNotFound, path unless info

        BFS::FileInfo.new(path: path, size: info.content_length, mtime: info.last_modified, content_type: info.content_type, metadata: norm_meta(info.metadata))
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NoSuchBucket, Aws::S3::Errors::NotFound
        raise BFS::FileNotFound, path
      end

      # Creates a new file and opens it for writing
      # @param [String] path
      # @param [Hash] opts options
      # @option opts [String] :encoding Custom encoding.
      # @option opts [String] :acl custom ACL override
      # @option opts [String] :server_side_encryption SSE override
      # @option opts [String] :storage_class storage class override
      def create(path, encoding: self.encoding, perm: self.perm, **opts, &block)
        path = full_path(path)
        opts = opts.merge(
          bucket: name,
          key: path,
        )
        opts[:acl] ||= @acl if @acl
        opts[:server_side_encryption] ||= @sse if @sse
        opts[:storage_class] ||= @storage_class if @storage_class

        temp = BFS::TempWriter.new(path, encoding: encoding, perm: perm) do |t|
          File.open(t, encoding: encoding) do |file|
            @client.put_object(opts.merge(body: file))
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
      # @param [String] path
      # @param [Hash] opts options
      # @option opts [String] :encoding Custom encoding.
      # @option opts [String] :tempdir Custom temp dir.
      def open(path, encoding: self.encoding, tempdir: nil, **opts, &block)
        path = full_path(path)
        temp = Tempfile.new(File.basename(path), tempdir, encoding: encoding)
        temp.close

        opts = opts.merge(
          response_target: temp.path,
          bucket: name,
          key: path,
        )
        @client.get_object(**opts)

        File.open(temp.path, encoding: encoding, &block)
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NoSuchBucket, Aws::S3::Errors::NotFound
        raise BFS::FileNotFound, trim_prefix(path)
      end

      # Deletes a file.
      def rm(path, **opts)
        path = full_path(path)
        opts = opts.merge(
          bucket: name,
          key: path,
        )
        @client.delete_object(**opts)
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NoSuchBucket, Aws::S3::Errors::NotFound # rubocop:disable Lint/SuppressedException
      end

      # Copies a file.
      def cp(src, dst, **opts)
        src = full_path(src)
        dst = full_path(dst)
        opts = opts.merge(
          bucket: name,
          copy_source: "/#{name}/#{src}",
          key: dst,
        )
        @client.copy_object(**opts)
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NoSuchBucket, Aws::S3::Errors::NotFound
        raise BFS::FileNotFound, trim_prefix(src)
      end

      private

      def init_client(**opts)
        config = {}
        config[:region] = opts[:region] if opts[:region]
        config[:credentials] = opts[:credentials] if opts[:credentials]
        config[:credentials] ||= Aws::Credentials.new(opts[:access_key_id].to_s, opts[:secret_access_key].to_s) if opts[:access_key_id]
        config[:credentials] ||= Aws::SharedCredentials.new(profile_name: opts[:profile_name]) if opts[:profile_name]

        Aws::S3::Client.new(config)
      end
    end
  end
end

BFS.register('s3') do |url, opts, block|
  prefix = BFS.norm_path(opts[:prefix] || url.path)
  opts[:prefix] = prefix.empty? ? nil : prefix
  opts = opts.slice(:prefix, :region, :sse, :access_key_id, :secret_access_key, :acl, :storage_class, :encoding)

  BFS::Bucket::S3.open url.host, **opts, &block
end
