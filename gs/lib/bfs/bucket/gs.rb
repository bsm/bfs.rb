require 'bfs'
require 'google/cloud/storage'
require 'cgi'

module BFS
  module Bucket
    # GS buckets are operating on Google Cloud Storage
    class GS < Abstract
      attr_reader :name

      # Initializes a new GoogleCloudStorage bucket.
      #
      # @param [String] name the bucket name.
      # @param [Hash] opts options.
      # @option opts [String] :project_id project ID. Defaults to GCP_PROJECT  env var. Required.
      # @option opts [String, Hash, Google::Auth::Credentials] :credentials
      #   the path to the keyfile as a String, the contents of the keyfile as a Hash, or a Google::Auth::Credentials object.
      # @option opts [Integer] :retries number of times to retry requests. Default: 3.
      # @option opts [Integer] :timeout request timeout, in seconds.
      # @option opts [String] :acl set the default ACL.
      # @option opts [Google::Cloud::Storage] :client custom client.
      def initialize(name, opts={})
        opts = opts.dup
        opts.keys.each do |key|
          val = opts.delete(key)
          opts[key.to_sym] = val unless val.nil?
        end
        opts[:project_id] ||= ENV['GCP_PROJECT'] || ENV['GCLOUD_PROJECT']

        acl    = opts.delete(:acl)
        client = opts.delete(:client) || Google::Cloud::Storage.new(opts)

        @name   = name.to_s
        @bucket = client.bucket(@name)
        @bucket.default_acl.send(:"#{acl}!") if @bucket.default_acl.respond_to?(:"#{acl}!")
      end

      # Lists the contents of a bucket using a glob pattern
      def ls(pattern='**/*', opts={})
        Enumerator.new do |y|
          @bucket.files(opts).each do |file|
            y << file.name if File.fnmatch?(pattern, file.name, File::FNM_PATHNAME)
          end
        end
      end

      # Info returns the object info
      def info(path, _opts={})
        path = norm_path(path)
        file = @bucket.file(path)
        raise BFS::FileNotFound, path unless file

        BFS::FileInfo.new(path, file.size, file.updated_at)
      end

      # Creates a new file and opens it for writing
      def create(path, opts={}, &block)
        path = norm_path(path)
        temp = BFS::TempWriter.new(path) do |t|
          File.open(t, binmode: true) do |file|
            @bucket.create_file(file, path, opts)
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
      def open(path, opts={}, &block)
        path = norm_path(path)
        file = @bucket.file(path)
        raise BFS::FileNotFound, path unless file

        temp = Tempfile.new(File.basename(path), binmode: true)
        temp.close
        file.download temp.path, opts

        File.open(temp.path, binmode: true, &block)
      end

      # Deletes a file.
      def rm(path, opts={})
        path = norm_path(path)
        file = @bucket.file(path)
        file.delete(opts) if file
      end

      # Copies a file.
      def cp(src, dst, opts={})
        src  = norm_path(src)
        file = @bucket.file(src)
        raise BFS::FileNotFound, src unless file

        file.copy(norm_path(dst), opts)
      end
    end
  end
end

BFS.register('gs') do |url|
  params = CGI.parse(url.query.to_s)

  BFS::Bucket::GS.new url.host,
    project_id: params.key?('project_id') ? params['project_id'].first : nil,
    acl: params.key?('acl') ? params['acl'].first : nil,
    timeout: params.key?('timeout') ? params['timeout'].first.to_i : nil,
    retries: params.key?('retries') ? params['retries'].first.to_i : nil
end
