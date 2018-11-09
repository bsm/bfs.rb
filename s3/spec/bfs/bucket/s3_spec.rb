require 'spec_helper'

RSpec.describe BFS::Bucket::S3 do
  let(:files) { {} }
  let :mock_client do
    client = double Aws::S3::Client

    allow(client).to receive(:put_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      files[opts[:key]] = opts[:body].read
      nil
    end

    allow(client).to receive(:get_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      data = files[opts[:key]]
      raise Aws::S3::Errors::NoSuchKey.new(nil, nil) unless data

      File.open(opts[:response_target], 'wb') {|f| f.write(data) }
      nil
    end

    allow(client).to receive(:delete_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      raise Aws::S3::Errors::NoSuchKey.new(nil, nil) unless files.key?(opts[:key])

      files.delete(opts[:key])
      nil
    end

    allow(client).to receive(:list_objects_v2).with(bucket: 'mock-bucket', continuation_token: nil) do |*|
      contents = files.keys.map {|key| Aws::S3::Types::Object.new(key: key) }
      double 'ListObjectsV2Response', contents: contents, next_continuation_token: ''
    end
    allow(client).to receive(:list_objects_v2).with(bucket: 'mock-bucket', max_keys: 1, prefix: 'a/b/c.txt') do |*|
      obj = Aws::S3::Types::Object.new(key: 'a/b/c.txt', size: 10, last_modified: Time.now)
      double 'ListObjectsV2Response', contents: [obj]
    end
    allow(client).to receive(:list_objects_v2).with(bucket: 'mock-bucket', max_keys: 1, prefix: 'missing.txt') do |*|
      double 'ListObjectsV2Response', contents: []
    end

    allow(client).to receive(:copy_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      src = opts[:copy_source].sub('/mock-bucket/', '')
      raise Aws::S3::Errors::NoSuchKey.new(nil, nil) unless files.key?(src)

      files[opts[:key]] = files[src]
      nil
    end

    client
  end

  subject { described_class.new('mock-bucket', client: mock_client) }
  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve('s3://mock-bucket?acl=private&region=eu-west-2')
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq('mock-bucket')
    expect(bucket.acl).to eq(:private)
  end
end
