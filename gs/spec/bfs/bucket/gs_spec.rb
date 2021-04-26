require 'spec_helper'

# silence warnings
module Google::Auth::CredentialsLoader
  def warn_if_cloud_sdk_credentials(*); end
  module_function :warn_if_cloud_sdk_credentials
end

bucket_name = 'bsm-bfs-unittest'

RSpec.describe BFS::Bucket::GS, gs: true do
  subject do
    described_class.new bucket_name, prefix: prefix
  end

  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  after do
    bucket = described_class.new bucket_name, prefix: prefix
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'resolves from URL' do
    bucket = BFS.resolve("gs://#{bucket_name}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(bucket_name)
    expect(bucket.instance_variable_get(:@prefix)).to be_nil
    bucket.close

    bucket = BFS.resolve("gs://#{bucket_name}/a/b/")
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
