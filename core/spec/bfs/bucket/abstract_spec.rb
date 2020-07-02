require 'spec_helper'

RSpec.describe BFS::Bucket::Abstract do
  it 'should open with a block' do
    sub_class = Class.new(described_class) do
      def close
        @closed = true
      end

      def closed?
        @closed == true
      end
    end

    bucket = nil
    sub_class.open do |bkt|
      expect(bkt).not_to be_closed
      bucket = bkt
    end
    expect(bucket).to be_instance_of(sub_class)
    expect(bucket).to be_closed
  end
end
