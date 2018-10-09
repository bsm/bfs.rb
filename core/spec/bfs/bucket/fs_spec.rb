require 'spec_helper'

RSpec.describe BFS::Bucket::FS do
  let(:tmpdir) { Dir.mktmpdir }
  after   { FileUtils.rm_rf tmpdir }
  subject { described_class.new(tmpdir) }

  it_behaves_like 'a bucket'
end
