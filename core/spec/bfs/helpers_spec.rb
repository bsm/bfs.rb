require 'spec_helper'

RSpec.describe BFS::TempWriter do
  let(:closer) { proc {} }
  subject { described_class.new 'test', nil, &closer }

  it 'should behave like a File' do
    missing = ::File.public_instance_methods - subject.public_methods
    expect(missing).to be_empty
  end

  it 'should exectute a closer block' do
    expect(closer).to receive(:call).with(subject.path)
    expect(subject.close).to be_truthy
  end
end
