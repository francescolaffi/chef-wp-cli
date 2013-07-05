#
# Cookbook Name:: wp
# Resource:: wp
#

include WpCli::ResourceConfig
include WpCli::Helpers

default_action :setup
#actions :setup

def initialiaze(*args)
  super
  config
  @url = norm_url(@name)
  @path = url2path(@name)
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
