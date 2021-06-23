require 'spec_helper'

RSpec.describe BFS::Bucket::SFTP, sftp: true do
  subject do
    described_class.new '127.0.0.1', port: 7023, user: 'user', password: 'pass', prefix: "upload/#{SecureRandom.uuid}"
  end

  it_behaves_like 'a bucket', content_type: false, metadata: false

  it 'resolves from URL' do
    bucket = BFS.resolve('sftp://user:pass@127.0.0.1:7023')
    expect(bucket).to be_instance_of(described_class)
    bucket.close

    bucket = BFS.resolve('sftp://user:pass@127.0.0.1:7023/a/b/')
    expect(bucket).to be_instance_of(described_class)
    bucket.close
  end
end
