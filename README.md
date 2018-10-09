# BFS

[![Build Status](https://travis-ci.org/bsm/bfs.png?branch=master)](https://travis-ci.org/bsm/bfs)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Minimalist abstraction for bucket storage.

## Installation

Add this to your Gemfile:

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
```
