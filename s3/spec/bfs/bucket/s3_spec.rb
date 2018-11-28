require 'spec_helper'

RSpec.describe BFS::Bucket::S3, if: ENV['BFSS3_TEST'] do
  scratch = { region: 'us-east-1', bucket: 'bsm-bfs-unittest' }.freeze
  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  subject do
    described_class.new scratch[:bucket], region: scratch[:region], prefix: prefix
  end
  after :all do
    bucket = described_class.new scratch[:bucket], region: scratch[:region], prefix: 'x/'
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve("s3://#{scratch[:bucket]}?acl=private&region=#{scratch[:region]}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(scratch[:bucket])
    expect(bucket.acl).to eq(:private)
  end

  it 'should enumerate over a large number of files' do
    bucket = described_class.new scratch[:bucket], region: scratch[:region], prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
  end
end
