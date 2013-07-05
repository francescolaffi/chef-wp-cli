#
# Cookbook Name:: wp
# Resource:: wp_exec
#

require 'chef/resource/execute'
require 'shellwords'

class Chef
  class Resource
    class WpExec < Chef::Resource::Execute

      identity_attr :name

      def initialize(name, run_context=nil)
        super
        @resource_name = :wp_exec
        @provider = Chef::Provider::WpExec
        @command = name.shellsplit.drop(1).shelljoin
        @cwd = ::File.join(node['wp']['base-path'], wp_url(name.shellsplit[0]))
        @user = node['wp']['user']
        @group = node['wp']['group']
        @arguments = {}
      end

      def arguments(arg=nil)
        set_or_return(
          :arguments,
          arg,
          :kind_of => Hash
        )
      end

      alias :args :arguments

    end
  end
end