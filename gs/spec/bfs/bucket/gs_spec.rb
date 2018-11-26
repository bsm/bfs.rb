require 'spec_helper'

RSpec.describe BFS::Bucket::GS do
  let(:contents)    { {} }
  let(:mock_client) { double Google::Cloud::Storage, bucket: mock_bucket }

  let :mock_bucket do
    bucket = double Google::Cloud::Storage::Bucket,
      default_acl: double(Google::Cloud::Storage::Bucket::Acl)
    allow(bucket).to receive(:create_file) do |io, name, _|
      contents[name] = double_file(name, io.read)
    end
    allow(bucket).to receive(:files) do |_|
      contents.values
    end
    allow(bucket).to receive(:file) do |name|
      contents[name]
    end
    bucket
  end

  def double_file(name, data)
    file = double Google::Cloud::Storage::File,
      name: name,
      data: data,
      size: data.bytesize,
      content_type: 'text/plain',
      metadata: {},
      updated_at: Time.now
    allow(file).to receive(:download) do |path, _|
      File.open(path, 'wb') {|f| f.write file.data }
    end
    allow(file).to receive(:delete) do |_|
      contents.delete(file.name)
      true
    end
    allow(file).to receive(:copy) do |dst, _|
      contents[dst] = double_file(dst, file.data)
    end
    file
  end

  subject { described_class.new 'mock-bucket', client: mock_client }
  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    expect(Google::Cloud::Storage).to receive(:new).with(project_id: 'my-project').and_return(mock_client)
    expect(mock_client).to receive(:bucket).with('mock-bucket').and_return(mock_bucket)
    expect(mock_bucket.default_acl).to receive(:private!).with(no_args)

    bucket = BFS.resolve('gs://mock-bucket?acl=private&project_id=my-project')
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq('mock-bucket')
  end
end
