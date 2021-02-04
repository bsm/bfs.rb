require 'spec_helper'

RSpec.describe BFS::Bucket::FTP, ftp: true do
  subject { described_class.new hostname, **conn_opts }

  let(:hostname) { '127.0.0.1' }
  let(:conn_opts) { { port: 7021, username: 'ftpuser', password: 'ftppass', prefix: SecureRandom.uuid } }

  after { subject.close }

  it_behaves_like 'a bucket',
                  content_type: false,
                  metadata: false

  it 'resolves from URL' do
    bucket = BFS.resolve('ftp://ftpuser:ftppass@127.0.0.1:7021')
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.instance_variable_get(:@client).pwd).to eq('/ftp/ftpuser')
    bucket.close

    bucket = BFS.resolve('ftp://ftpuser:ftppass@127.0.0.1:7021/a/b/')
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.instance_variable_get(:@client).pwd).to eq('/ftp/ftpuser/a/b')
    bucket.close
  end
end
