#
# Cookbook Name:: wp
# Resource:: wp_exec
#

require 'chef/resource/execute'
require File.join(File.dirname(__FILE__), 'module_helpers')
require 'shellwords'

class Chef
  class Resource
    class WpExec < Chef::Resource::Execute

      include WpCli::Helpers

      identity_attr :name

      def initialize(*args)
        super
        @resource_name = :wp_exec
        @provider = Chef::Provider::WpExec
        @command = @name.shellsplit.drop(1).shelljoin
        @cwd = url2path(@name.shellsplit[0])
        @user = node['wp']['user']
        @group = node['wp']['group']
        @arguments = {}
      end

      def arguments(val=nil)
        set_or_return(:arguments, val, :kind_of => Hash)
      end

      alias :args :arguments

    end
  end
end