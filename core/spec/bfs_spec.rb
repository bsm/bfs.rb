require 'spec_helper'

RSpec.describe BFS do
  it 'should resolve' do
    bucket = BFS.resolve("file://#{Dir.tmpdir}")
    expect(bucket).to be_instance_of(BFS::Bucket::FS)
    bucket.close
  end

  it 'should resolve with block' do
    BFS.resolve("file://#{Dir.tmpdir}") do |bucket|
      expect(bucket).to be_instance_of(BFS::Bucket::FS)
      expect(bucket).to receive(:close)
    end
  end
end
