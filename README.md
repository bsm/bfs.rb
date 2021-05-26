# BFS

[![Build Status](https://github.com/bsm/bfs.rb/actions/workflows/test.yml/badge.svg)](https://github.com/bsm/bfs.rb/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Abstraction for bucket storage.

## Supported backends

- [In-memory](https://rubygems.org/gems/bfs) - for testing
- [Local file system](https://rubygems.org/gems/bfs) - supports `file://` URLs
- [(S)FTP](https://rubygems.org/gems/bfs-ftp) - supports `ftp://` and `sftp://` URLs
- [Google Cloud Storage](https://rubygems.org/gems/bfs-gs) - supports `gs://` URLs
- [Amazon S3](https://rubygems.org/gems/bfs-s3) - supports `s3://` URLs
- [SCP](https://rubygems.org/gems/bfs-scp) - supports `scp://` URLs

## Installation

Add this to your Gemfile, e.g. for S3 support:

```ruby
gem 'bfs-s3'
```

Then execute:

```shell
$ bundle
```

## Usage

```ruby
require 'bfs/s3'

# connect to a bucket
bucket = BFS.resolve('s3://my-bucket?region=eu-west-2')

# create a file
bucket.create 'path/to/file.txt' do |f|
  f.write 'Hello World!'
end

# read that file
bucket.open 'path/to/file.txt' do |f|
  puts f.gets
end

# delete that file
bucket.rm 'path/to/file.txt'

# close the bucket again
bucket.close
```

Or, as a block:

```ruby
require 'bfs/fs'

BFS.resolve('file:///absolute/path') do |bucket|
  bucket.ls('**').each do |file|
    puts file
  end
end
```
