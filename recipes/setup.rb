#
# Cookbook Name:: wp
# Recipe:: cli
#
# Author:: Francesco Laffi
# License: MIT
#

include_recipe 'wp::cli'

require 'chef/mixin/deep_merge'

node['wp']['installs'].each {|name, args|
  mywp = wp name do
    args Chef::Mixin::DeepMerge.deep_merge(args, node['wp']['globals'].to_hash)
    action :setup
  end
  Chef::Log.info("access #{name} #{mywp.config.class} #{mywp.config.inspect}")
}