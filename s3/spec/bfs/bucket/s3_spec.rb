require 'spec_helper'

sandbox  = { region: 'us-east-1', bucket: 'bsm-bfs-unittest' }.freeze
run_spec = \
  begin
    c = Aws::SharedCredentials.new
    if c.loadable?
      s = Aws::S3::Client.new(region: sandbox[:region], credentials: c)
      s.head_bucket(bucket: sandbox[:bucket])
      true
    else
      false
    end
  rescue Aws::Errors::ServiceError
    false
  end

RSpec.describe BFS::Bucket::S3, if: run_spec do
  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  subject do
    described_class.new sandbox[:bucket], region: sandbox[:region], prefix: prefix
  end
  after :all do
    bucket = described_class.new sandbox[:bucket], region: sandbox[:region], prefix: 'x/'
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve("s3://#{sandbox[:bucket]}?acl=private&region=#{sandbox[:region]}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(sandbox[:bucket])
    expect(bucket.acl).to eq(:private)
  end

  it 'should enumerate over a large number of files' do
    bucket = described_class.new sandbox[:bucket], region: sandbox[:region], prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
  end
end
