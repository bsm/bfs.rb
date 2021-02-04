require 'spec_helper'

RSpec.describe BFS, core: true do
  it 'resolves' do
    bucket = described_class.resolve("file://#{Dir.tmpdir}")
    expect(bucket).to be_instance_of(BFS::Bucket::FS)
    bucket.close
  end

  it 'resolves with block' do
    described_class.resolve("file://#{Dir.tmpdir}") do |bucket|
      expect(bucket).to be_instance_of(BFS::Bucket::FS)
      expect(bucket).to receive(:close)
    end
  end
end
