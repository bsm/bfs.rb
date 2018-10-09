require 'spec_helper'

RSpec.describe BFS::Bucket::S3 do
  let(:client)  { double('Aws::S3::Client') }
  let(:files)   { {} }
  subject { described_class.new('mock-bucket', client: client) }

  # stub put_object calls and store file data
  before do
    allow(client).to receive(:put_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      files[opts[:key]] = opts[:body].read
      nil
    end
  end

  # stub get_object calls
  before do
    allow(client).to receive(:get_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      data = files[opts[:key]]
      raise Aws::S3::Errors::NoSuchKey.new(nil, nil) unless data

      File.open(opts[:response_target], 'w') {|f| f.write(data) }
      nil
    end
  end

  before do
    allow(client).to receive(:delete_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      raise Aws::S3::Errors::NoSuchKey.new(nil, nil) unless files.key?(opts[:key])

      files.delete(opts[:key])
      nil
    end
  end

  # stub list_objects_v2 calls
  before do
    allow(client).to receive(:list_objects_v2).with(bucket: 'mock-bucket') do |*|
      contents = files.keys.map {|key| Aws::S3::Types::Object.new(key: key) }
      double 'ListObjectsV2Response', contents: contents
    end
  end

  # stub list_objects_v2, single object calls
  before do
    match = double 'ListObjectsV2Response', contents: [
      Aws::S3::Types::Object.new(key: 'a/b/c.txt', size: 10, last_modified: Time.now),
    ]
    no_match = double 'ListObjectsV2Response', contents: []

    allow(client).to receive(:list_objects_v2).with(bucket: 'mock-bucket', max_keys: 1, prefix: 'a/b/c.txt').and_return(match)
    allow(client).to receive(:list_objects_v2).with(bucket: 'mock-bucket', max_keys: 1, prefix: 'missing.txt').and_return(no_match)
  end

  # stub copy_object calls
  before do
    allow(client).to receive(:copy_object).with(hash_including(bucket: 'mock-bucket')) do |opts|
      src = opts[:copy_source].sub('/mock-bucket/', '')
      raise Aws::S3::Errors::NoSuchKey.new(nil, nil) unless files.key?(src)

      files[opts[:key]] = files[src]
      nil
    end
  end

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve('s3://mock-bucket?acl=private&region=eu-west-2')
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq('mock-bucket')
    expect(bucket.acl).to eq(:private)
  end
end
