require 'spec_helper'

bucket_name = 'bsm-bfs-unittest'

RSpec.describe BFS::Bucket::S3, s3: true do
  subject do
    described_class.new bucket_name, prefix: prefix
  end

  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  after :all do # rubocop:disable RSpec/BeforeAfterAll
    bucket = described_class.new bucket_name, prefix: 'x/'
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'resolves from URL' do
    bucket = BFS.resolve("s3://#{bucket_name}/?acl=private&encoding=binary")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(bucket_name)
    expect(bucket.acl).to eq(:private)
    expect(bucket.encoding).to eq('binary')
    expect(bucket.instance_variable_get(:@prefix)).to be_nil
    bucket.close

    bucket = BFS.resolve("s3://#{bucket_name}/a/b/")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(bucket_name)
    expect(bucket.instance_variable_get(:@prefix)).to eq('a/b')
    bucket.close
  end

  it 'enumerates over a large number of files' do
    bucket = described_class.new bucket_name, prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
    bucket.close
  end
end
