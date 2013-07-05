#
# Cookbook Name:: wp
# Attributes:: setup
#
# Author:: Francesco Laffi
# License: MIT
#

default['wp']['globals'] = {}
default['wp']['installs'] = {}

node['wp']['installs'].keys.each{|name|
  default['wp']['installs'][name] = {
    'path' => "/var/www/#{name}",
    'dbname' => "#{name}",
    'dbuser' => 'wordpress',
    'dbpass' => 'wordpress',
    'dbimport' => false,
    'url' => node['fqdn'],
    'title' => 'My WordPress Site',
    'admin_name' => 'admin',
    'admin_email' => 'admin@example.org',
    'admin_password' => 'admin',
    'network' => false,
    'clean_install' => false,
    'plugins' => {},
    'themes' => {},
    'theme' => '',
    'update_core' => false,
    'update_plugins' => false,
    'update_themes' => false,
  }
} if node['wp'].key?('installs') && node['wp']['installs'].any?