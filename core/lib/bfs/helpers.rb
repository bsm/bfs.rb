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

    def perform(&block)
      return self unless block

      begin
        yield self
        close
      ensure
        close!
      end
    end

    def close
      return if closed?

      tempfile = __getobj__
      tempfile.close
      @closer&.call(tempfile.path)
      true
    ensure
      tempfile.unlink
    end
  end
end
