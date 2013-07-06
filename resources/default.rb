#
# Cookbook Name:: wp
# Resource:: wp
#

include WpCli::ResourceConfig
include WpCli::Helpers

#actions :setup
default_action :setup

attribute :path, :kind_of => String

def initialize(*args)
  super
  @url = norm_url(@name)
  @path = url2path(@name)
end

def url(val=nil)
  val = norm_url(val) if !val.nil?
  set_or_return(:url, val, :kind_of => String)
end

def host
  @config['host'] || url2host(@url)
end

def base
  @config['base'] || url2base(@url)
end

def network?
  @config['network'].is_a?(Hash)
end

def subdomains?
  network? && @config['network']['subdomains']
end

def server_name
  @config['server_name'] || strip_www(host)
end

def server_aliases
  @config['server_aliases'] || [server_name, "#{subdomains? ? '*' : 'www'}.#{server_name}"]
end

def default_config
  {
    'dbname' => @name,
    'dbuser' => 'wordpress',
    'dbpass' => 'wordpress',
    'title' => 'My WordPress Site',
    'admin_email' => 'admin@example.org',
    'admin_password' => 'admin',
  }
end

def validate_config(conf)
  conf['dbname'] = conf['dbname'].gsub(/[^\w]+/, '_').gsub(/_+/, '_')
  conf
end