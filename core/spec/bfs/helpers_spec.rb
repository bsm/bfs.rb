require 'spec_helper'

RSpec.describe BFS::Writer, core: true do
  subject { described_class.new 'test', &on_commit }

  let(:on_commit) { proc { true } }

  it 'supports custom params' do
    subject = described_class.new 'test', perm: 0o640, &on_commit
    expect(subject.stat.mode).to eq(0o100640)
    expect(subject.commit).to be(true)
  end

  it 'executes a on_commit block' do
    expect(on_commit).to have_received(:call).with(subject.path).once
    expect(subject.commit).to be(true)
    expect(subject.commit).to be(false)
  end

  it 'may skip on_commit block' do
    expect(on_commit).not_to have_received(:call)
    expect(subject.discard).to be(true)
  end

  it 'does not auto-commit on close' do
    expect(on_commit).not_to have_received(:call)
    expect(subject.close).to be_nil
  end
end
