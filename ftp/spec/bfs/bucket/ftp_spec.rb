require 'spec_helper'

sandbox  = { host: '127.0.0.1', port: 7021, username: 'ftpuser', password: 'ftppass' }.freeze
run_spec = \
  begin
    ftp = Net::FTP.new sandbox[:host], sandbox
    ftp.list
    ftp.close
    true
  rescue Errno::ECONNREFUSED, Net::FTPError
    false
  end

RSpec.describe BFS::Bucket::FTP, if: run_spec do
  subject { described_class.new sandbox[:host], sandbox.merge(prefix: SecureRandom.uuid) }
  after   { subject.close }

  it_behaves_like 'a bucket',
    content_type: false,
    metadata: false

  it 'should resolve from URL' do
    bucket = BFS.resolve('ftp://ftpuser:ftppass@127.0.0.1:7021')
    expect(bucket).to be_instance_of(described_class)
  end
end
