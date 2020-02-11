require 'spec_helper'

sandbox  = { host: '127.0.0.1', opts: { port: 7022, user: 'root', password: 'root' } }.freeze
run_spec = \
  begin
    Net::SCP.start sandbox[:host], nil, sandbox[:opts].merge(timeout: 1) do |scp|
      scp.session.exec!('hostname')
    end
    true
  rescue Net::SSH::Exception, Errno::ECONNREFUSED => e
    warn "WARNING: unable to run #{File.basename __FILE__}: #{e.message}"
    false
  end

RSpec.describe BFS::Bucket::SCP, if: run_spec do
  context 'absolute' do
    subject { described_class.new sandbox[:host], sandbox[:opts].merge(prefix: SecureRandom.uuid) }
    after   { subject.close }

    it_behaves_like 'a bucket', content_type: false, metadata: false
  end

  context 'relative' do
    subject { described_class.new sandbox[:host], sandbox[:opts].merge(prefix: "~/#{SecureRandom.uuid}") }
    after   { subject.close }

    it_behaves_like 'a bucket', content_type: false, metadata: false
  end

  it 'should resolve from URL' do
    bucket = BFS.resolve('scp://root:root@127.0.0.1:7022')
    expect(bucket).to be_instance_of(described_class)
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

  context 'preserve' do
    subject { described_class.new sandbox[:host], sandbox[:opts].merge(prefix: "~/#{SecureRandom.uuid}", preserve: true) }
    after   { subject.close }

    it 'should preserve file permissions on upload' do
      subject.create('perms.txt', permissions: 755) do |f|
        f.write('access')
      end
      expect(subject.info('perms.txt').metadata[:permissions]).to(eq(755))
    end

    xit 'should preserve file permissions on download' do

    end
  end
end
