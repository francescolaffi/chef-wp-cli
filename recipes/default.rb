#
# Cookbook Name:: wpcli
# Recipe:: default
#
# Author:: Francesco Laffi
# License: MIT
#

require 'shellwords'

include_recipe 'git'
include_recipe 'curl'

include_recipe 'php'
include_recipe 'php::module_mysql'

include_recipe 'mysql::server'
include_recipe 'database::mysql'
include_recipe 'apache2'
include_recipe 'apache2::mod_php5'

git '/usr/local/wp-cli' do
  repository 'git://github.com/wp-cli/wp-cli.git'
  reference 'master'
  enable_submodules true
  action :checkout
  user 'root'
  group 'root'
end

execute 'install wp-cli' do
  command 'utils/dev-build'
  creates '/bin/wp'
  cwd '/usr/local/wp-cli'
  user 'root'
  group 'root'
end

node['wpcli']['installs'].each {|name, args|
  wpcli "#{name} create" do
    path args['path']
    args node['wpcli']['globals'].to_hash.merge(args)
    action :setup
  end
}


