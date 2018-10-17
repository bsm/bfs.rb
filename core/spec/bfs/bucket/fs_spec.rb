require 'spec_helper'

RSpec.describe BFS::Bucket::FS do
  let(:tmpdir) { Dir.mktmpdir }
  after   { FileUtils.rm_rf tmpdir }
  subject { described_class.new(tmpdir) }

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    File.open(File.join(tmpdir, 'test.txt'), 'w') {|f| f.write 'TESTDATA' }

    bucket = BFS.resolve("file://#{tmpdir}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.ls).to eq(['test.txt'])

    bucket = BFS.resolve("file://#{tmpdir}/test.txt?scope=dir")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.ls).to eq(['test.txt'])

    bucket = BFS.resolve("file://#{tmpdir}/test.txt?scope=root")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.instance_variable_get(:@root).to_s).to eq('/')
  end
end
