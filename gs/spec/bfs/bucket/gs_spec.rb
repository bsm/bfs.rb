require 'spec_helper'

# silence warnings
module Google::Auth::CredentialsLoader
  def warn_if_cloud_sdk_credentials(*); end
  module_function :warn_if_cloud_sdk_credentials # rubocop:disable Style/AccessModifierDeclarations
end

sandbox = { project: 'bogus', bucket: 'bsm-bfs-unittest' }.freeze

RSpec.describe BFS::Bucket::GS, gs: true do
  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  subject do
    described_class.new sandbox[:bucket], project_id: sandbox[:project], prefix: prefix
  end
  after :all do
    bucket = described_class.new sandbox[:bucket], project_id: sandbox[:project], prefix: 'x/'
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve("gs://#{sandbox[:bucket]}/?project_id=#{sandbox[:project]}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(sandbox[:bucket])
    expect(bucket.instance_variable_get(:@prefix)).to be_nil
    bucket.close

    bucket = BFS.resolve("gs://#{sandbox[:bucket]}/a/b/")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(sandbox[:bucket])
    expect(bucket.instance_variable_get(:@prefix)).to eq('a/b')
    bucket.close
  end

  it 'should enumerate over a large number of files' do
    bucket = described_class.new sandbox[:bucket], project_id: sandbox[:project], prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
    bucket.close
  end
end
