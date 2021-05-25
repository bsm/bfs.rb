RSpec.shared_examples 'a bucket' do |features|
  features ||= {}

  before do
    subject.write '/a/b.txt', 'TESTDATA-b'
    subject.write 'a/b/c.txt', 'TESTDATA-c',
                  content_type: 'text/plain',
                  metadata: { 'meta-KEY' => 'VaLuE' }
    subject.write 'a/b/c/d.txt', 'TESTDATA-d'
    subject.write 'a/b/c/d/e.txt', 'TESTDATA-e'
  end

  def be_recent_time
    be_within(90).of(Time.now)
  end

  after do
    subject.close
  end

  it 'lists' do
    expect(subject.ls).to be_a(Enumerator)
    expect(subject.ls.to_a).to match_array [
      'a/b.txt',
      'a/b/c.txt',
      'a/b/c/d.txt',
      'a/b/c/d/e.txt',
    ]
    expect(subject.ls('**/c*').to_a).to match_array [
      'a/b/c.txt',
    ]
    expect(subject.ls('a/b/*/*').to_a).to match_array [
      'a/b/c/d.txt',
    ]
    expect(subject.ls('x/**').to_a).to be_empty
  end

  it 'globs' do
    expect(subject.glob).to be_a(Enumerator)
    expect(subject.glob.to_a.sort_by(&:path)).to match [
      include(path: 'a/b.txt', size: 10, mtime: be_recent_time),
      include(path: 'a/b/c.txt', size: 10, mtime: be_recent_time),
      include(path: 'a/b/c/d.txt', size: 10, mtime: be_recent_time),
      include(path: 'a/b/c/d/e.txt', size: 10, mtime: be_recent_time),
    ]
    expect(subject.glob('**/c*').to_a).to match [
      include(path: 'a/b/c.txt', size: 10, mtime: be_recent_time),
    ]
    expect(subject.glob('a/b/*/*').to_a).to match [
      include(path: 'a/b/c/d.txt', size: 10, mtime: be_recent_time),
    ]
    expect(subject.glob('x/**').to_a).to be_empty
  end

  it 'returns info' do
    info = subject.info('/a/b/c.txt')
    expect(info.path).to eq('a/b/c.txt')
    expect(info.size).to eq(10)
    expect(info.mtime).to be_recent_time

    expect(info.content_type).to eq('text/plain') unless features[:content_type] == false
    expect(info.metadata).to eq('Meta-Key' => 'VaLuE') unless features[:metadata] == false

    expect { subject.info('missing.txt') }.to raise_error(BFS::FileNotFound)
  end

  it 'write/reads' do
    expect(subject.read('a/b.txt')).to eq('TESTDATA-b')
    expect(subject.read('/a/b.txt')).to eq('TESTDATA-b')
    subject.write('a/b.txt', 'NEWDATA')

    data = subject.read('a/b.txt')
    expect(data).to eq('NEWDATA')
    expect(data.encoding).to eq(Encoding.default_external)
  end

  it 'write/reads (block)' do
    subject.create('x.txt') {|io| io.write 'DATA-x' }
    read = nil
    subject.open('x.txt') {|io| read = io.gets }
    expect(read).to eq('DATA-x')
  end

  it 'write/reads (iterative)' do
    w = subject.create('y.txt')
    w.write('DATA-y')
    w.commit

    r = subject.open('y.txt')
    expect(r.read).to eq('DATA-y')
    r.close
  end

  it 'write/reads (custom encoding + perm)' do
    w = subject.create('y.txt', encoding: 'iso-8859-15', perm: 0o644)
    w.write('DATA-y')
    w.commit

    r = subject.open('y.txt', encoding: 'iso-8859-15')
    data = r.read
    expect(data).to eq('DATA-y')
    expect(data.encoding).to eq(Encoding::ISO_8859_15)
    r.close

    info = subject.info('y.txt')
    expect(info.mode).to eq(0).or eq(0o644)
  end

  it 'raises FileNotFound if not found on read' do
    expect { subject.read('not/found.txt') }.to raise_error(BFS::FileNotFound)
  end

  it 'gracefullies abort on errors' do
    expect do
      subject.create('x.txt') do |io|
        io.write 'TESTDATA'
        raise 'doh!'
      end
    end.to raise_error(RuntimeError, 'doh!')

    expect { subject.read('x.txt') }.to raise_error(BFS::FileNotFound)
  end

  it 'removes' do
    subject.rm('a/b/c.txt')
    subject.rm('not/found.txt')
    expect(subject.ls).to match_array [
      'a/b.txt',
      'a/b/c/d.txt',
      'a/b/c/d/e.txt',
    ]
  end

  it 'copies' do
    subject.cp('a/b/c.txt', 'x.txt')
    expect(subject.ls.count).to eq(5)
    expect(subject.read('x.txt')).to eq('TESTDATA-c')

    expect { subject.cp('missing.txt', 'x.txt') }.to raise_error(BFS::FileNotFound)
  end

  it 'moves' do
    subject.mv('a/b/c.txt', 'x.txt')
    expect(subject.ls.count).to eq(4)
    expect(subject.read('x.txt')).to eq('TESTDATA-c')
    expect { subject.read('a/b/c.txt') }.to raise_error(BFS::FileNotFound)

    expect { subject.mv('missing.txt', 'x.txt') }.to raise_error(BFS::FileNotFound)
  end
end
