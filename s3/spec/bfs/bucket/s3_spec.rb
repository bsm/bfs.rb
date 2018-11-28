require 'spec_helper'

S3_SANDBOX = { region: 'us-east-1', bucket: 'bsm-bfs-unittest' }.freeze
run_spec = \
  begin
    c = Aws::S3::Client.new(region: S3_SANDBOX[:region], credentials: Aws::SharedCredentials.new)
    c.head_bucket(bucket: S3_SANDBOX[:bucket])
    true
  rescue Aws::Errors::ServiceError
    false
  end

RSpec.describe BFS::Bucket::S3, if: run_spec do
  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  subject do
    described_class.new S3_SANDBOX[:bucket], region: S3_SANDBOX[:region], prefix: prefix
  end
  after :all do
    bucket = described_class.new S3_SANDBOX[:bucket], region: S3_SANDBOX[:region], prefix: 'x/'
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve("s3://#{S3_SANDBOX[:bucket]}?acl=private&region=#{S3_SANDBOX[:region]}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(S3_SANDBOX[:bucket])
    expect(bucket.acl).to eq(:private)
  end

  it 'should enumerate over a large number of files' do
    bucket = described_class.new S3_SANDBOX[:bucket], region: S3_SANDBOX[:region], prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
  end
end
