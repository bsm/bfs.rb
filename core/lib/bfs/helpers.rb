require 'tempfile'
require 'delegate'

module BFS
  class TempWriter < DelegateClass(::Tempfile)
    def initialize(name, tempdir: nil, perm: nil, **opts, &closer)
      @closer = closer

      tempfile = ::Tempfile.new(File.basename(name.to_s), tempdir, **opts)
      tempfile.chmod(perm) if perm
      super tempfile
    end

    def perform
      return self unless block_given?

      begin
        yield self
        close
      ensure
        close!
      end
    end

    def close
      return if closed?

      super.tap do
        @closer&.call(path)
      end
      unlink
    end
  end
end
