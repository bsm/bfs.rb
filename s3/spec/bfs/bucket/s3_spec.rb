require 'spec_helper'

sandbox = { bucket: 'bsm-bfs-unittest' }.freeze

RSpec.describe BFS::Bucket::S3, s3: true do
  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  subject do
    described_class.new sandbox[:bucket], prefix: prefix
  end
  after :all do
    bucket = described_class.new sandbox[:bucket], prefix: 'x/'
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve("s3://#{sandbox[:bucket]}/?acl=private&encoding=binary")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(sandbox[:bucket])
    expect(bucket.acl).to eq(:private)
    expect(bucket.encoding).to eq('binary')
    expect(bucket.instance_variable_get(:@prefix)).to be_nil
    bucket.close

    bucket = BFS.resolve("s3://#{sandbox[:bucket]}/a/b/")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(sandbox[:bucket])
    expect(bucket.instance_variable_get(:@prefix)).to eq('a/b')
    bucket.close
  end

  it 'should enumerate over a large number of files' do
    bucket = described_class.new sandbox[:bucket], prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
    bucket.close
  end
end
