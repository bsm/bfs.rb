require 'spec_helper'

RSpec.describe BFS::Bucket::Abstract, core: true do
  it 'opens with a block' do
    sub_class = Class.new(described_class) do
      def close
        @closed = true
      end

      def closed?
        @closed == true
      end
    end

    bucket = nil
    result = sub_class.open do |bkt|
      expect(bkt).not_to be_closed
      bucket = bkt
      21
    end
    expect(result).to eq(21)
    expect(bucket).to be_instance_of(sub_class)
    expect(bucket).to be_closed
  end
end
