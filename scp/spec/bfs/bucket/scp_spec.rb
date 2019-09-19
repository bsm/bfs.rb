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
  subject { described_class.new sandbox[:host], sandbox[:opts].merge(prefix: SecureRandom.uuid) }
  after   { subject.close }

  it_behaves_like 'a bucket',
    content_type: false,
    metadata: false

  it 'should resolve from URL' do
    bucket = BFS.resolve('scp://root:root@127.0.0.1:7022')
    expect(bucket).to be_instance_of(described_class)
  end
end
