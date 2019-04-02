RSpec.shared_examples 'a bucket' do |features={}|
  before do
    subject.write '/a/b.txt', 'TESTDATA-b'
    subject.write 'a/b/c.txt', 'TESTDATA-c',
      content_type: 'text/plain',
      metadata: { 'meta-key' => 'value' }
    subject.write 'a/b/c/d.txt', 'TESTDATA-d'
    subject.write 'a/b/c/d/e.txt', 'TESTDATA-e'
  end

  after do
    subject.close
  end

  it 'should ls' do
    expect(subject.ls).to be_a(Enumerator)
    # expect(subject.ls.to_a).to match_array [
    #   'a/b.txt',
    #   'a/b/c.txt',
    #   'a/b/c/d.txt',
    #   'a/b/c/d/e.txt',
    # ]
    # expect(subject.ls('**/c*').to_a).to match_array [
    #   'a/b/c.txt',
    # ]
    expect(subject.ls('a/b/*/*').to_a).to match_array [
      'a/b/c/d.txt',
    ]
    # expect(subject.ls('x/**').to_a).to be_empty
  end

  it 'should return info' do
    info = subject.info('/a/b/c.txt')
    expect(info.path).to eq('a/b/c.txt')
    expect(info.size).to eq(10)
    expect(info.mtime).to be_within(2).of(Time.now)

    expect(info.content_type).to eq('text/plain') unless features[:content_type] == false
    expect(info.metadata).to eq('meta-key' => 'value') unless features[:metadata] == false

    expect { subject.info('missing.txt') }.to raise_error(BFS::FileNotFound)
  end

  it 'should write/read' do
    expect(subject.read('a/b.txt')).to eq('TESTDATA-b')
    expect(subject.read('/a/b.txt')).to eq('TESTDATA-b')
    subject.write('a/b.txt', 'NEWDATA')

    data = subject.read('a/b.txt')
    expect(data).to eq('NEWDATA')
    expect(data.encoding).to eq(Encoding::BINARY)
  end

  it 'should write/read (block)' do
    subject.create('x.txt') {|io| io.write 'DATA-x' }
    read = nil
    subject.open('x.txt') {|io| read = io.gets }
    expect(read).to eq('DATA-x')
  end

  it 'should write/read (iterative)' do
    w = subject.create('y.txt')
    w.write('DATA-y')
    w.close

    r = subject.open('y.txt')
    expect(r.read).to eq('DATA-y')
    r.close
  end

  it 'should raise FileNotFound if not foudn on read' do
    expect { subject.read('not/found.txt') }.to raise_error(BFS::FileNotFound)
  end

  it 'should remove' do
    subject.rm('a/b/c.txt')
    subject.rm('not/found.txt')
    expect(subject.ls).to match_array [
      'a/b.txt',
      'a/b/c/d.txt',
      'a/b/c/d/e.txt',
    ]
  end

  it 'should copy' do
    subject.cp('a/b/c.txt', 'x.txt')
    expect(subject.ls.count).to eq(5)
    expect(subject.read('x.txt')).to eq('TESTDATA-c')

    expect { subject.cp('missing.txt', 'x.txt') }.to raise_error(BFS::FileNotFound)
  end

  it 'should move' do
    subject.mv('a/b/c.txt', 'x.txt')
    expect(subject.ls.count).to eq(4)
    expect(subject.read('x.txt')).to eq('TESTDATA-c')
    expect { subject.read('a/b/c.txt') }.to raise_error(BFS::FileNotFound)

    expect { subject.mv('missing.txt', 'x.txt') }.to raise_error(BFS::FileNotFound)
  end
end
