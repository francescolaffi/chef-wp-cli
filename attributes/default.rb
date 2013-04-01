#
# Cookbook Name:: wp-cli
# Attributes:: wp-cli
#
# Author:: Francesco Laffi
# License: MIT
#

default['wpcli']['installs'] = {}
default['wpcli']['globals'] = {}
default['wpcli']['user'] = 'root'
default['wpcli']['group'] = 'root'

node['wpcli']['installs'].keys.each{|name|
  default['wpcli']['installs'][name] = {
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
} if node['wpcli']['installs'].is_a?(Hash)
