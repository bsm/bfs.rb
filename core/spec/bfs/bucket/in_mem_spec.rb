require 'spec_helper'

RSpec.describe BFS::Bucket::InMem, core: true do
  it_behaves_like 'a bucket'
end
