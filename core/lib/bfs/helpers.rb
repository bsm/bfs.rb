require 'tempfile'
require 'delegate'

module BFS
  class Writer < DelegateClass(::Tempfile)
    module Mixin
      def perform
        return self unless block_given?

        begin
          yield self
          commit
        ensure
          discard
        end
      end

      def commit
        close
        return false if @on_commit.nil?

        @on_commit.call(commit_ref)
        true
      ensure
        discard
      end

      def discard
        @on_commit = nil
        close!
      end
    end

    include Mixin

    def initialize(name, tempdir: nil, perm: nil, **opts, &on_commit)
      @on_commit = on_commit

      tempfile = ::Tempfile.new(File.basename(name.to_s), tempdir, **opts)
      tempfile.chmod(perm) if perm
      super tempfile
    end

    alias commit_ref path
  end
end
