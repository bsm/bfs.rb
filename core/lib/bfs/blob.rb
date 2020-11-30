module BFS
  # Blobs are references to single blob objects within a bucket.
  class Blob
    attr_reader :path

    # Behaves like new, but accepts an optional block.
    # If a block is given, blobs are automatically closed after the block is yielded.
    def self.open(url)
      blob = new(url)
      return blob unless block_given?

      begin
        yield blob
      ensure
        blob.close
      end
    end

    def initialize(url)
      url = url.is_a?(::URI) ? url.dup : URI.parse(url)
      @path = BFS.norm_path(url.path)

      url.path = '/'
      @bucket = BFS.resolve(url)

      BFS.defer(self, :close)
    end

    # Info returns the blob info.
    def info(**opts)
      @bucket.info(path, **opts)
    end

    # Creates the blob and opens it for writing.
    # If a block is passed the writer is automatically committed in the end.
    # If no block is passed, you must manually call #commit to persist the
    # result.
    def create(**opts, &block)
      @bucket.create(path, **opts, &block)
    end

    # Opens the blob for reading.
    # May raise BFS::FileNotFound.
    def open(**opts, &block)
      @bucket.open(path, **opts, &block)
    end

    # Deletes the blob.
    def rm(**opts)
      @bucket.rm(path, **opts)
    end

    # Shortcut method to read the contents of the blob.
    def read(**opts)
      self.open(**opts, &:read)
    end

    # Shortcut method to write data to blob.
    def write(data, **opts)
      create(**opts) {|f| f.write data }
    end

    # Moves blob to dst.
    def mv(dst, **opts)
      dst = BFS.norm_path(dst)
      @bucket.mv(path, dst, **opts)
      @path = dst
    end

    # Closes the underlying bucket connection.
    def close
      @bucket.close
    end
  end
end
