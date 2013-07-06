#
# Cookbook Name:: wp
# Recipe:: apache
#
# Author:: Francesco Laffi
# License: MIT
#

include_recipe 'wp::setup'

include_recipe 'apache2::mod_php5'

vhosts = {}

node['wp']['installs'].each {|url, args|
  
  wpres = wp url do
    config args
    action :nothing
  end

  is_network = args['network'].is_a?(Hash)
  is_subdomain = is_network && args['network']['subdomains']
  
  # htaccess
  prefix = wpres.network? ? (wpres.subdomains? ? 'ms-subdomains' : 'ms-subfolders') : 'singlesite'
  cookbook_file "#{url} .htaccess" do
    path "#{wpres.path}/.htaccess"
    source "#{prefix}.htaccess"
    owner node['wp']['user']
    group node['wp']['group']
    action :create_if_missing
  end

  vhosts[wpres.server_name] = [wpres.path, wpres.server_aliases]
}

vhosts.each {|host, info|
  web_app host do
    docroot info[0]
    server_name host
    server_aliases info[1]
  end
}


