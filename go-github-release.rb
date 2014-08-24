#!/usr/bin/env ruby

# Example usage:
#  1. Puts following as 'Gorelfile' in the top of a git repository
#
#  release do |config|
#    config.token "..."
#    config.os "linux darwin"
#    config.arch "amd64"
#  end
#
#  2. run this script with 'build' or 'upload' command
#  % go-github-release.rb upload

require 'fileutils'
require 'json'
require 'open3'

class GitHubReleaseAPIClient
  def initialize(token, owner, repo)
    @token = token
    @owner = owner
    @repo = repo
    @api_url = "https://api.github.com/repos/#{@owner}/#{@repo}"
    @upload_url = "https://uploads.github.com/repos/#{@owner}/#{@repo}"

    @releases = nil
  end

  def create_release(tag, opts = {})
    r = lookup_tag(tag)
    return r if r
    data = {
      'tag_name' => tag,
      'target_commitish' => 'master',
      'name' => tag,
      'prerelease' => false,
      'draft' => true,
    }.merge(opts)
    post("/releases", data)
  end

  def upload_asset(release, filename)
    name = File.basename(filename)
    path = "/releases/#{release['id']}/assets?name=#{name}"
    upload(path, filename)
  end

  def lookup_tag(tag)
    releases.find {|r| r['tag_name'] == tag }
  end

  def releases
    @releases || (@releases = get('/releases'))
  end

  def get(path = '/releases')
    send_request('GET', path)
  end

  def post(path = '/releases', data = {})
    result = send_request('POST', path, data)
    @releases = nil
    result
  end

  def patch(path = '/releases', data = {})
    result = send_request('PATCH', path, data)
    @releases = nil
    result
  end

  def delete(path = '/releases')
    result = send_request('DELETE', path)
    @releases = nil
    result
  end

  def send_request(method, path, body = nil)
    cmd = "curl --fail -sS #{@api_url}#{path} -X #{method} -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token #{@token}'"
    if body
      body_json = JSON.dump(body)
      cmd << " -d '#{body_json}'" if body
    end
    o, e, s = Open3.capture3(cmd)
    raise "#{e}" unless s.success?
    JSON.parse(o)
  end

  def upload(path, filename)
    mimetype = `file --mime -b #{filename} 2> /dev/null`.chop
    raise "Can't determine mime type" if mimetype.empty?
    cmd = "curl --fail -sS #{@upload_url}#{path} -X POST -H 'Accept: application/vnd.github.v3+json' -H 'Authorization: token #{@token}' -H 'Content-Type: #{mimetype}' --data-binary @#{filename}"
    o, e, s = Open3.capture3(cmd)
    raise "#{e}" unless s.success?
    JSON.parse(o)
  end

end

class ReleaseBuilder
  def initialize(version = nil, repository = '.')
    Dir.chdir(repository)
    @repository = repository
    @owner, @repo = owner_and_repo
    @version = version || guess_version
    @builddir = 'build' # TODO: temporary
    @bindir = File.join(@builddir, 'bin')
    @distdir = File.join(@builddir, 'dist')
  end

  def build(os = 'linux darwin windows', arch = 'amd64')
    FileUtils.mkdir_p(@bindir)
    cmd = "gox -os='#{os}' -arch='#{arch}' -output '#{@bindir}/{{.OS}}_{{.Arch}}/{{.Dir}}' ./..."
    o, e, s = Open3.capture3(cmd)
    raise "#{e}" unless s.success?
  end

  def compress
    FileUtils.mkdir_p(@distdir)
    Dir.glob("#{@bindir}/*") do |d|
      osarch = File.basename(d)
      zippath = File.absolute_path(File.join(@distdir, "#{@repo}_#{osarch}.zip"))
      Dir.chdir(d) {
        cmd = "zip #{zippath} ./*"
        o, e, s = Open3.capture3(cmd)
        raise "#{e}" unless s.success?
      }
    end
  end

  def upload(token)
    client = GitHubReleaseAPIClient.new(token, @owner, @repo)
    release = client.create_release(@version)
    Dir.glob("#{@distdir}/*.zip") do |z|
      begin
        STDOUT.puts "Uploading #{z}..."
        client.upload_asset(release, z)
      rescue => e
        STDERR.puts "Failed to upload: #{e}"
      end
    end
  end

  def owner_and_repo
    toplevel = `git rev-parse --show-toplevel`.chop
    raise "Not in a git repository" if toplevel.empty?
    repo = File.basename(toplevel)
    owner = File.basename(File.dirname(toplevel))
    return owner, repo
  end

  def guess_version
    begin
      version = `git grep -i 'const version'`.scan(/.*"(.+)"$/).last.first
      "v#{version}"
    rescue
      raise "Can't guess VERSION"
    end
  end
end

class ReleaseConfig
  def initialize
    @token_value = nil
    @os_value = 'linux darwin windows'
    @arch_value = 'amd64 386'
  end

  attr_reader :token_value, :os_value, :arch_value

  def token(value)
    @token_value = value
  end

  def os(value)
    @os_value = value
  end

  def arch(value)
    @arch_value = value
  end
end

$do_upload = true

def release(&block)
  config = ReleaseConfig.new
  config.instance_eval(&block)

  builder = ReleaseBuilder.new
  builder.build(config.os_value, config.arch_value)
  builder.compress
  if $do_upload
    raise "'token' must be specified" unless config.token_value
    builder.upload(config.token_value)
  end
end

def usage
  STDERR.puts("Usage: #{__FILE__} (build|upload)")
  exit(1)
end

# TODO: Add a option to check whether the same release is already uploaded
# TODO: Add a feature to remove assets/releases

if __FILE__ == $0
  raise "No Gorelfile" unless File.exists?('Gorelfile')
  case ARGV[0]
  when 'build'
    $do_upload = false
  when 'upload'
    # nothing to do
  else
    usage
  end

  load File.expand_path('Gorelfile')
end
