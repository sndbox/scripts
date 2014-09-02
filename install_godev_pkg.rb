#!/usr/bin/env ruby

raise "$GOPATH not set." unless ENV.has_key?('GOPATH')
Dir.chdir(ENV['GOPATH']) do
  [
    'code.google.com/p/go.tools/cmd/godoc',
    'code.google.com/p/rog-go/exp/cmd/godef',
    'github.com/monochromegane/the_platinum_searcher/...',
    'github.com/nsf/gocode',
  ].each do |pkg|
    system("go get -u #{pkg}")
  end
end
