module BFS
  class FileNotFound < StandardError
    attr_reader :path

    def initialize(path)
      @path = path
      super "File not found: #{path}"
    end
  end
end
