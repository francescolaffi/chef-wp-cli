#
# Cookbook Name:: wp
# Recipe:: apache
#
# Author:: Francesco Laffi
# License: MIT
#

include_recipe 'wp::setup'

include_recipe 'apache2::mod_php5'

node['wp']['installs'].each {|name, args|
  
  path = wp_path(name, args['path'])
  
  # htaccess
  prefix = args['network'].is_a?(Hash) ? (args['network']['subdomains'] ? 'ms-subdomains' : 'ms-subfolders') : 'singlesite'
  cookbook_file "#{name} .htaccess" do
    path "#{path}/.htaccess"
    source "#{prefix}.htaccess"
    owner node['wp']['user']
    group node['wp']['group']
    action :create_if_missing
  end

  # set up apache vhost
  host = args['host'] || wp_host(wp_url(args['url']))
  aliases = args['server_aliases'] || ([strip_www(host), "*.#{strip_www(host)}"])
  web_app name do
    docroot path
    server_name host
    server_aliases aliases
    allow_override 'All'
  end
}


