#
# Cookbook Name:: wp
# Provider:: wp
#

require 'shellwords'

def load_current_resource
end

action :setup do 
  wpname = @new_resource.name
  wppath = @new_resource.config['path']
  args = @new_resource.config
  
  # delete directory if clean install
  directory "#{wpname} delete #{wppath}" do
    path wppath
    recursive true
    action :delete
  end if args['clean-install'] == true
  
  # create directory
  directory wppath do
    mode '0755'
    recursive true
    user node['wp']['user']
    group node['wp']['group']
    action :create
  end
  
  # download wp core 
  cli 'core download', ['locale','version','force'] do
    creates ::File.join(wppath, 'wp-load.php')
  end
  
  mysql_info = {
    :host => 'localhost',
    :username => 'root',
    :password => node['mysql']['server_root_password']
  }
  
  # drop database if clean install
  mysql_database "#{wpname} drop #{args['dbname']}" do
    database_name args['dbname']
    connection mysql_info
    action :drop
  end if args['clean-install'] == true
  
  # create database
  mysql_database args['dbname'] do
    connection mysql_info
    action :create
  end
  
  # create db user and grant all
  mysql_database_user args['dbuser'] do
    connection mysql_info
    password args['dbpass']
    privileges ['ALL']
    database_name args['dbname']
    action [:create, :grant]
  end
  
  # create wp-config.php
  cli 'core config', ['dbname','dbuser','dbpass','dbprefix'] do
    creates ::File.join(wppath, 'wp-config.php')
  end
  
  cli "db import #{args['dbimport'].shellescape}" do
    only_if {::File.exists?(args['dbimport'])}
    not_if 'wp core is-installed', :cwd => wppath
  end if args['dbimport']
  
  # install wordpress
  cli 'core install', ['url','title','admin_name','admin_email','admin_password'] do
    not_if 'wp core is-installed', :cwd => wppath
  end
  
  # install network
  cli 'core install-network', args['network'], ['title','base'], ['subdomains'] do
    only_if 'wp eval "exit(is_multisite()?1:0);"', :cwd => wppath
  end if args['network'].is_a? Hash
  
  # update wordpress
  cli 'core update', ['version'], ['force'] do
    only_if 'wp core is-installed', :cwd => wppath
  end if args['update-core'] == true
  
  # update plugins
  cli 'plugin update-all' do
    only_if 'wp core is-installed', :cwd => wppath
  end if args['update-plugins'] == true
  
  # update themes
  cli 'theme update-all' do
    only_if 'wp core is-installed', :cwd => wppath
  end if args['update-themes'] == true


  #set up plugins
  args['plugins'].each { |plugin, opt|
    opt['source'].chomp!('/') if opt['source']
    if opt['source'] && !opt['source'].empty? then
      # must-use plugin to fix symlinked plugins url
      tmp_path = ::File.join(Chef::Config[:file_cache_path], 'wpcli-SymlinkedPluginsUrlFixer.php')
      cookbook_file 'tmp SymlinkedPluginsUrlFixer' do
        path tmp_path
        source 'SymlinkedPluginsUrlFixer.php'
        backup false
        owner node['wp']['user']
        group node['wp']['group']
      end
      execute "#{wpname} SymlinkedPluginsUrlFixer" do
        command "mkdir -p \"$(wp eval 'echo WPMU_PLUGIN_DIR;')\";
                cp #{tmp_path.shellescape} \"$(wp eval 'echo WPMU_PLUGIN_DIR;')/SymlinkedPluginsUrlFixer.php\""
        cwd wppath
        user node['wp']['user']
        group node['wp']['group']
      end    
    
      plugin_path_subcommand = opt['must-use'] ? 'wp eval "echo WPMU_PLUGIN_DIR;"' : 'wp plugin path';
      
      execute "#{wpname} plugin symlink #{plugin}" do
        command "ln -s #{opt['source'].shellescape} \"$(#{plugin_path_subcommand})/#{plugin}\""
        cwd wppath
        user node['wp']['user']
        group node['wp']['group']
        not_if "wp plugin status #{plugin}", :cwd => wppath
      end
    else
      cli "plugin install #{(opt['zip'] || plugin).shellescape}", opt, ['version'] do
        not_if "wp plugin status #{plugin}", :cwd => wppath
      end
    end
    
    cli "plugin update #{plugin}", opt, ['version'] if opt['update'] == true
    
    cli "plugin activate #{plugin}", opt, [], ['network'] if opt['active'] == true
    
    cli "plugin deactivate #{plugin}", opt, [], ['network'] if opt['active'] == false
    
  } if args['plugins'].is_a? Hash
  
  # set up themes
  args['themes'].each { |theme, opt|
    opt['source'].chomp!('/') if opt['source']
    if opt['source'] && !opt['source'].empty? then
      execute "#{wpname} symlink theme #{theme}" do
        command "ln -s #{opt['source'].shellescape} \"$(wp theme path)/#{theme}\""
        user node['wp']['user']
        group node['wp']['group']
        not_if "wp theme status #{theme}", :cwd => wppath
      end
    else
      cli "theme install #{(opt['zip'] || theme).shellescape}", opt, ['version'] do
        not_if "wp theme status #{theme}", :cwd => wppath
      end
    end
    
    cli "theme update #{theme}", opt, ['version'] if opt['update'] == true
    
  } if args['themes'].is_a? Hash
  
  # activate theme  
  cli "theme activate #{args['theme']}" if args['theme'] && !args['theme'].empty?
  
  #rewrite rules
  if args['rewrite'].is_a?(Hash) && args['rewrite']['structure']
    cli "rewrite structure #{args['rewrite']['structure']}", args['rewrite'], ['category-base', 'tag-base']
  end
    
  # set up network sites
  if args['network'].is_a? Hash
    if args['network']['subdomains'].nil?
      url_format = "#{args['url']}/%s"
    else
      url_format = strip_www(args['url'])
      url_format = "%s.#{url_format}"
    end
    
    args['network']['sites'].each do |slug, site_args|
      site_args['slug'] ||= slug
      site_args['url'] ||= url_format % site_args['slug']
      
      cli 'site create', site_args, ['slug','title','email','network_id'], ['private']
      
      site_args['plugins'].each do |plugin|
        cli "plugin activate #{plugin}", site_args, ['url']
      end if site_args['plugins'].is_a? Array
      
      cli "theme activate #{site_args['theme']}", site_args, ['url'] if site_args['theme'] && !site_args['theme'].empty?
    end if args['network']['s'].is_a? Hash
  end
end

def cli(name, *args, &block)
  args.unshift(@new_resource.config) if !args.first.is_a?(Hash)
  path = @new_resource.config['path']
  wp_exec "#{@new_resource.name} #{name}" do
    args sel_args(*args)
    cwd path
    instance_eval(&block) if block
  end
end

def sel_args(args = {}, which_assoc = [], which_bool = [])
  sel = []
  sel.concat args.select{|k,v| which_assoc.include? k}
  sel.concat args.select{|k,v| which_bool.include?(k) && v}.map{|k,v|[k,'']}
  Hash[sel]
end