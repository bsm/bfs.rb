require 'spec_helper'

# silence warnings
module Google::Auth::CredentialsLoader
  def warn_if_cloud_sdk_credentials(*); end
  module_function :warn_if_cloud_sdk_credentials # rubocop:disable Style/AccessModifierDeclarations
end

sandbox  = { project: 'bogus', bucket: 'bsm-bfs-unittest' }.freeze
run_spec = \
  begin
    s = Google::Cloud::Storage.new(project_id: sandbox[:project])
    !s.bucket(sandbox[:bucket]).nil?
  rescue Signet::AuthorizationError
    false
  end

RSpec.describe BFS::Bucket::GS, if: run_spec do
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
    bucket = BFS.resolve("gs://#{sandbox[:bucket]}/?acl=private&project_id=#{sandbox[:project]}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(sandbox[:bucket])
    expect(bucket.instance_variable_get(:@prefix)).to be_nil

    bucket = BFS.resolve("gs://#{sandbox[:bucket]}/a/b/")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(sandbox[:bucket])
    expect(bucket.instance_variable_get(:@prefix)).to eq('a/b')
  end

  it 'should enumerate over a large number of files' do
    bucket = described_class.new sandbox[:bucket], project_id: sandbox[:project], prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
  end
end
