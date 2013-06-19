#
# Cookbook Name:: wpcli
# Provider:: wpcli
#

require 'shellwords'
require 'mixlib/shellout'

def load_current_resource
  @name = @new_resource.name.shellsplit[0]
  
  if @new_resource.path
    @path = ::File.join(@new_resource.path, "")
  else
    @path = "/var/www/#{@name}/"
  end
end

action :run do
  path = @path

  commands = []
  commands << @new_resource.command if @new_resource.command
  commands << @new_resource.code.lines.map(&:chomp) if @new_resource.code
  commands << @new_resource.name.shellsplit.drop(1).shelljoin if commands.empty?
  
  args_str = args_to_s(@new_resource.args || {})
  
  antifail = @new_resource.ignore_failure
  exitcodes = @new_resource.ignore_failure ? [0,1] : [0]
  
  commands.each { |com|
    execute "wp #{com}#{args_str}" do
      cwd path
      ignore_failure antifail
      returns exitcodes
      user node['wpcli']['user']
      group node['wpcli']['group']
    end
  }
end

action :setup do 
  name, path = [@name, @path]

  args = {
    'dbname' => "#{name}",
    'dbuser' => 'wordpress',
    'dbpass' => 'wordpress',
    'url' => node['fqdn'],
    'title' => 'My WordPress Site',
    'admin_email' => 'admin@example.org',
    'admin_password' => 'admin',
  }.merge(@new_resource.args || {})
  
  # remove protocol and trailing slash
  args['url'] = args['url'][%r{^(?:.+://)?(.+?)/*$}, 1]
  
  directory path do
    mode '0755'
    recursive true
    user node['wpcli']['user']
    group node['wpcli']['group']
    action :nothing
  end
  
  # delete directory if needed
  directory "delete #{path}" do
    path path
    recursive true
    action :delete
  end if args['clean-install'] == true
  
  # create directory
  directory path do
    recursive true
    action :create
  end
  
  # download wp core 
  wpcli "#{name} download" do
    command 'core download'
    args sel_args(args, ['locale','version','force'])
    path path
    not_if {::File.exists? "#{path}/wp-load.php"}
  end
  
  mysql_info = {
    :host => 'localhost',
    :username => 'root',
    :password => node['mysql']['server_root_password']
  }
  
  # drop database if needed
  mysql_database "drop #{args['dbname']}" do
    database_name args['dbname']
    connection mysql_info
    action :drop
  end if args['clean-install'] == true
  
  execute "#{name} import db" do
    command "mysql -u#{mysql_info[:username].shellescape} -p#{mysql_info[:password].shellescape} \
      #{args['dbname'].shellescape} < #{(args['dbimport'] || '').shellescape}"
    cwd path
    user node['wpcli']['user']
    group node['wpcli']['group']
    action :nothing
    only_if {args['dbimport'] && ::File.exists?(args['dbimport'])}
  end
  
  # create database
  mysql_database args['dbname'] do
    connection mysql_info
    action :create
    notifies :run, "execute[#{name} import db]", :immediately
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
  wpcli "#{name} core config" do
    args sel_args(args, ['dbname','dbuser','dbpass','dbprefix'])
    path path
    not_if {::File.exists? "#{path}/wp-config.php" }
  end
  
  # install wordpress
  wpcli "#{name} core install" do
    path path
    args sel_args(args, ['url','title','admin_name','admin_email','admin_password'])
    not_if 'wp core is_installed', :cwd => path
  end
  
  # install network
  wpcli "#{name} install-network" do
    path path
    command 'core install-network'
    args sel_args(args['network'], ['title','base','subdomains'])
    only_if 'wp eval "exit(is_multisite()?1:0);"', :cwd => path
  end if args['network']
  
  # update wordpress
  wpcli "#{name} core update" do
    path path
    args sel_args(args, ['version','force'])
    only_if 'wp core is_installed', :cwd => path
  end if args['update-core'] == true
  
  # update plugins
  wpcli "#{name} plugin update-all" do
    path path
    only_if 'wp core is_installed', :cwd => path
  end if args['update-plugins'] == true
  
  # update themes
  wpcli "#{name} theme update-all" do
    path path
    only_if 'wp core is_installed', :cwd => path
  end if args['update-themes'] == true


  #set up plugins
  args['plugins'].each { |plugin, opt|
    opt['source'].chomp!('/') if opt['source']
    if opt['source'] && !opt['source'].empty? then
      # must-use plugin to fix symlinked plugins url
      cookbook_file "tmp SymlinkedPluginsUrlFixer" do
        path '/tmp/SymlinkedPluginsUrlFixer.php'
        source 'SymlinkedPluginsUrlFixer.php'
        backup false
        owner node['wpcli']['user']
        group node['wpcli']['group']
      end
      execute "#{name} SymlinkedPluginsUrlFixer" do
        command 'mkdir -p $(wp eval "echo WPMU_PLUGIN_DIR;");
                 cp /tmp/SymlinkedPluginsUrlFixer.php $(wp eval "echo WPMU_PLUGIN_DIR;")/SymlinkedPluginsUrlFixer.php'
        cwd path
        user node['wpcli']['user']
        group node['wpcli']['group']
      end    
    
      plugin_path_subcommand = opt['must-use'] ? 'wp eval "echo WPMU_PLUGIN_DIR;"' : 'wp plugin path';
      
      execute "#{name} plugin symlink #{plugin}" do
        command "ln -s #{opt['source'].shellescape} $(#{plugin_path_subcommand})/#{plugin.shellescape}"
        cwd path
        user node['wpcli']['user']
        group node['wpcli']['group']
        not_if "wp plugin status #{plugin}", :cwd => path
      end
    else
      wpcli "#{name} plugin install #{(opt['zip'] || plugin).shellescape}" do
        path path
        args sel_args(opt, ['version'])
        not_if "wp plugin status #{plugin}", :cwd => path
      end
    end
    
    wpcli "#{name} plugin update #{plugin}" do
      path path
      args sel_args(opt, ['version'])
    end if opt['update'] == true
    
    wpcli "#{name} plugin activate #{plugin}" do
      path path
      args sel_args(opt, ['network'])
    end if opt['active'] == true
    
    wpcli "#{name} plugin deactivate #{plugin}" do
      path path
      args sel_args(opt, ['network'])
    end if opt['active'] == false
    
  } if args['plugins'].is_a? Hash
  
  # set up themes
  args['themes'].each { |theme, opt|
    opt['source'].chomp!('/') if opt['source']
    if opt['source'] && !opt['source'].empty? then
      execute "#{name} symlink theme #{theme}" do
        command "ln -s #{opt['source'].shellescape} $(wp theme path)/#{theme.shellescape}"
        user node['wpcli']['user']
        group node['wpcli']['group']
        not_if "wp theme status #{theme}", :cwd => path
      end
    else
      wpcli "#{name} theme install #{(opt['zip'] || theme).shellescape}" do
        path path
        args sel_args(opt, ['version'])
        not_if "wp theme status #{theme}", :cwd => path
      end
    end
    
    wpcli "#{name} theme update #{theme}" do
      path path
      args sel_args(opt, ['version'])
    end if opt['update'] == true
    
  } if args['themes'].is_a? Hash
  
  # activate theme  
  wpcli "#{name} theme activate #{args['theme']}" do
    path path
  end if args['theme']
    
  # set up network blogs
  if args['network'].is_a? Hash
    if args['network']['subdomains'].nil?
      url_format = "#{args['url']}/%s"
    else
      url_format = strip_www(args['url'])
      url_format = "%s.#{url_format}"
    end
    
    args['network']['blogs'].each { |slug, blog_args|
      blog_args['slug'] ||= slug
      blog_args['url'] ||= url_format % blog_args['slug']
      
      wpcli "#{name} blog create" do
        path sel_args(blog_args, ['slug', 'title','site_id','email','private'])
      end
      
      blog_args['plugins'].each{ |plugin|
        wpcli "#{name} plugin activate #{plugin}" do
          path path
          args sel_args(blog_args, ['url'])
        end
      } if blog_args['plugins'].is_a? Array
      
      wpcli "#{name} theme activate #{blog_args['theme']}" do
        path path
        args sel_args(blog_args, ['url'])
      end if blog_args['theme']
    } if args['network']['blogs'].is_a? Hash
  end
  
  host = args['host'] || args['url'][%r{[^/]+}]
  aliases = args['server_aliases'] || ([strip_www(host), "*.#{strip_www(host)}"])
  
  # set up apache vhost
  web_app name do
    docroot path
    server_name host
    server_aliases aliases
    allow_override 'All'
  end
end

def args_to_s(args = {})
  args_str = ''
  args.each { |k,v|
    next if v.nil?
    key = "--#{k.to_s.shellescape}" if [String,Symbol].include? k.class
    arg = v.to_s.shellescape unless v === ''
    equal = '=' if key && arg
    args_str +=" #{key}#{equal}#{arg}"
  }
  args_str
end

def sel_args(args = {}, which = [])
  Hash[args.select{|k,v| which.include? k}]
end

def strip_www(url)
  url.start_with?('www.') ? url[4..-1] : url
end