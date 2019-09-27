require 'tempfile'
require 'delegate'

module BFS
  class TempWriter < DelegateClass(::Tempfile)
    def initialize(name, opts={}, &closer)
      @closer   = closer
      @tempfile = ::Tempfile.new(File.basename(name.to_s), opts)
      super @tempfile
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
