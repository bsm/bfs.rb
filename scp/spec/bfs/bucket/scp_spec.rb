require 'spec_helper'

RSpec.describe BFS::Bucket::SCP, scp: true do
  let(:hostname) { '127.0.0.1' }
  let(:conn_opts) { { port: 7022, user: 'root', password: 'root', prefix: prefix } }
  let(:prefix) { SecureRandom.uuid }

  subject { described_class.new hostname, **conn_opts }
  after { subject.close }

  context 'absolute' do
    it_behaves_like 'a bucket', content_type: false, metadata: false
  end

  context 'relative' do
    let(:prefix) { "~/#{SecureRandom.uuid}" }

    it_behaves_like 'a bucket', content_type: false, metadata: false
  end

  it 'should resolve from URL' do
    bucket = BFS.resolve('scp://root:root@127.0.0.1:7022')
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.instance_variable_get(:@prefix)).to be_nil
    bucket.close

    bucket = BFS.resolve('scp://root:root@127.0.0.1:7022/a/b/')
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.instance_variable_get(:@prefix)).to eq('a/b/')
    bucket.close
  end

  it 'should handle absolute and relative paths' do
    abs = BFS::Blob.new("scp://root:root@127.0.0.1:7022/#{SecureRandom.uuid}/file.txt")
    abs.create {|w| w.write 'absolute' }

    rel = BFS::Blob.new("scp://root:root@127.0.0.1:7022/~/#{SecureRandom.uuid}/file.txt")
    rel.create {|w| w.write 'relative' }

    expect(abs.read).to eq('absolute')
    expect(rel.read).to eq('relative')

    abs.close
    rel.close
  end

  it 'should support custom perms' do
    blob = BFS::Blob.new("scp://root:root@127.0.0.1:7022/#{SecureRandom.uuid}/file.txt")
    blob.create(perm: 0o666) {|w| w.write 'foo' }
    expect(blob.info.mode).to eq(0o666)
    blob.close
  end
end
