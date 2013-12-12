#
# Cookbook Name:: wp
# Recipe:: cli
#
# Author:: Francesco Laffi
# License: MIT
#

include_recipe 'git'
include_recipe 'curl'

include_recipe 'php'
include_recipe 'php::module_mysql'
include_recipe 'mysql::client'
include_recipe 'database::mysql'

# create wpcli dir
directory node['wp']['wpcli-dir'] do
  recursive true
end

# download installer
remote_file "#{node['wp']['wpcli-dir']}/installer.sh" do
  source 'https://raw.github.com/wp-cli/wp-cli.github.com/master/installer.sh'
  mode 0755
  action :create_if_missing
end

node.set['wp']['wpcli-bin'] = ::File.join(node['wp']['wpcli-dir'], 'bin', 'wp')

# run installer
bash 'install wp-cli' do
  code './installer.sh'
  cwd node['wp']['wpcli-dir']
  environment 'INSTALL_DIR' => node['wp']['wpcli-dir'],
              'VERSION' => node['wp']['wpcli-version']
  creates node['wp']['wpcli-bin']
end

# link wp bin
link node['wp']['wpcli-link'] do
  to node['wp']['wpcli-bin']
end if node['wp']['wpcli-link']

