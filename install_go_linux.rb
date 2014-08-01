#!/usr/bin/env ruby

require 'tmpdir'

DEFAULT_VERSION = '1.3'
DEFAULT_DEST = File.join(ENV['HOME'], 'local')

DOWNLOAD_URL = 'http://golang.org/dl/'

def download(version)
  url = DOWNLOAD_URL + "go#{version}.linux-amd64.tar.gz"
  raise "Failed to download #{url}" unless system("wget #{url}")
end

def untar(dest, version)
  command = "tar -C #{dest} -xzf go#{version}.linux-amd64.tar.gz"
  raise "Failed to untar" unless system(command)
end

def install(version, dest)
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      download(version)
      untar(dest, version)
    end
  end
end

install(DEFAULT_VERSION, DEFAULT_DEST)
