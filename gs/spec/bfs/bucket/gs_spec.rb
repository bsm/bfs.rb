require 'spec_helper'

# silence warnings
module Google::Auth::CredentialsLoader
  def warn_if_cloud_sdk_credentials(*); end
  module_function :warn_if_cloud_sdk_credentials # rubocop:disable Style/AccessModifierDeclarations
end

RSpec.describe BFS::Bucket::GS, if: ENV['BFSGS_TEST'] do
  scratch = { project: 'bsm-tech', bucket: 'bsm-bfs-unittest' }.freeze
  let(:prefix) { "x/#{SecureRandom.uuid}/" }

  subject do
    described_class.new scratch[:bucket], project_id: scratch[:project], prefix: prefix
  end
  after :all do
    bucket = described_class.new scratch[:bucket], project_id: scratch[:project], prefix: 'x/'
    bucket.ls.each {|name| bucket.rm(name) }
  end

  it_behaves_like 'a bucket'

  it 'should resolve from URL' do
    bucket = BFS.resolve("gs://#{scratch[:bucket]}?acl=private&project_id=#{scratch[:project]}")
    expect(bucket).to be_instance_of(described_class)
    expect(bucket.name).to eq(scratch[:bucket])
  end

  it 'should enumerate over a large number of files' do
    bucket = described_class.new scratch[:bucket], project_id: scratch[:project], prefix: 'm/'
    expect(bucket.ls('**/*').count).to eq(2121)
  end
end
