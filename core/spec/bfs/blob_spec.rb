require 'spec_helper'

RSpec.describe BFS::Blob, core: true do
  describe 'default' do
    let(:bucket) { BFS::Bucket::InMem.new }
    before       { allow(BFS).to receive(:resolve).and_return(bucket) }
    subject      { described_class.new('memtest://bucket/path/to/file.txt') }
    after        { subject.close }

    it 'should move' do
      expect(subject.path).to eq('path/to/file.txt')
      expect { subject.mv('/to/other/path.txt') }.to raise_error(BFS::FileNotFound)

      subject.write('TESTDATA')
      subject.mv('/to/other/path.txt')
      expect(subject.path).to eq('to/other/path.txt')
    end

    it 'should write/read' do
      expect { subject.read }.to raise_error(BFS::FileNotFound)
      subject.write('TESTDATA', content_type: 'text/plain', metadata: { 'x-key' => 'val' })

      info = subject.info
      expect(info).to eq(
        path: 'path/to/file.txt',
        size: 8,
        mtime: info.mtime,
        content_type: 'text/plain',
        mode: 0,
        metadata: { 'X-Key' => 'val' },
      )
      expect(info.mtime).to be_within(1).of(Time.now)

      expect(subject.read).to eq('TESTDATA')
    end
  end

  describe 'file system' do
    let(:tmpdir) { Dir.mktmpdir }
    let(:path)   { "#{tmpdir}/path/to/file.txt".sub('/', '') }
    after   { FileUtils.rm_rf tmpdir }
    subject { described_class.new("file:///#{path}") }

    it 'should move' do
      expect(subject.path).to eq(path)
      expect { subject.mv("#{tmpdir}/to/other/path.txt") }.to raise_error(BFS::FileNotFound)

      subject.write('TESTDATA')
      subject.mv("#{tmpdir}/to/other/path.txt")

      expect(subject.path).to eq("#{tmpdir}/to/other/path.txt".sub('/', ''))
      expect(Pathname.glob("#{tmpdir}/**/*").select(&:file?).map(&:to_s)).to eq [
        "#{tmpdir}/to/other/path.txt",
      ]
    end

    it 'should write/read' do
      expect { subject.read }.to raise_error(BFS::FileNotFound)

      subject.write('TESTDATA', content_type: 'text/plain', metadata: { 'x-key' => 'val' })
      expect(subject.read).to eq('TESTDATA')

      info = subject.info
      expect(info).to eq(
        path: path,
        size: 8,
        mtime: info.mtime,
        mode: 0o600,
        metadata: {},
      )
      expect(info.mtime).to be_within(1).of(Time.now)

      expect(Pathname.glob("#{tmpdir}/**/*").select(&:file?).map(&:to_s)).to eq [
        "#{tmpdir}/path/to/file.txt",
      ]
    end
  end
end
