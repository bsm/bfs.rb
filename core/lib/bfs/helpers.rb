require 'tempfile'

module BFS
  class TempWriter
    def initialize(name, opts={}, &closer)
      @closer = closer
      @tempfile = ::Tempfile.new(File.basename(name.to_s), opts)
    end

    def path
      @tempfile.path
    end

    def write(data)
      @tempfile.write(data)
    end

    def closed?
      @tempfile.closed?
    end

    def close
      return if closed?

      path = @tempfile.path
      @tempfile.close
      @closer&.call(path)
      @tempfile.unlink
    end
  end
end
