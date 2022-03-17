require 'spec_helper'

RSpec.describe BFS::Bucket::FS, core: true do
  subject { described_class.new(tmpdir) }

  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.rm_rf tmpdir }

  it_behaves_like 'a bucket',
                  content_type: false,
                  metadata: false

  it 'resolves from URL' do
    File.binwrite(File.join(tmpdir, 'test.txt'), 'TESTDATA')

    bucket = BFS.resolve("file://#{tmpdir}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.ls.to_a).to eq(['test.txt'])
    bucket.close
  end

  it 'supports custom perms on #initialize' do
    blob = BFS::Blob.new("file://#{tmpdir}/test.txt?perm=0666")
    blob.create {|w| w.write 'foo' }
    expect(blob.info.mode).to eq(0o666)
    blob.close
  end

  it 'supports custom perms on #create' do
    blob = BFS::Blob.new("file://#{tmpdir}/test.txt")
    blob.create(perm: 0o666) {|w| w.write 'foo' }
    expect(blob.info.mode).to eq(0o666)
    blob.close
  end
end
