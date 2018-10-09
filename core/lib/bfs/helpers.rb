require 'tempfile'

module BFS
  class TempWriter
    def initialize(name, &closer)
      @closer = closer
      @tempfile = ::Tempfile.new(File.basename(name.to_s))
    end

    def path
      @tempfile.path
    end

    def write(data)
      @tempfile.write(data)
    end

    def close
      path = @tempfile.path
      @tempfile.close
      @closer.call(path) if @closer
      @tempfile.unlink
    end
  end
end
