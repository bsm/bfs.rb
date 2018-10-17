require 'spec_helper'

RSpec.describe BFS::Blob do
  let(:bucket) { BFS::Bucket::InMem.new }
  before       { allow(BFS).to receive(:resolve).and_return(bucket) }
  subject      { described_class.new('memtest://bucket/path/to/file.txt') }

  it 'should move' do
    expect(subject.path).to eq('path/to/file.txt')
    expect { subject.mv('/to/other/path.txt') }.to raise_error(BFS::FileNotFound)

    subject.write('TESTDATA')
    subject.mv('/to/other/path.txt')
    expect(subject.path).to eq('to/other/path.txt')
  end

  it 'should write/read' do
    expect { subject.read }.to raise_error(BFS::FileNotFound)
    subject.write('TESTDATA')

    info = subject.info
    expect(info).to eq(BFS::FileInfo.new('path/to/file.txt', 8, info.mtime))
    expect(info.mtime).to be_within(1).of(Time.now)

    expect(subject.read).to eq('TESTDATA')
  end
end
