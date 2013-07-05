#
# Cookbook Name:: wp
# Provider:: wp_exec
#

require 'chef/provider/execute'
require 'shellwords'

class Chef
  class Provider
    class WpExec < Chef::Provider::Execute

      include WpCli::Helperss

      def action_run
        args_str = args_to_s(@new_resource.args)

        converge_by("wp #{@new_resource.command} #{args_str} [#{@new_resource.cwd}]") do 
          @new_resource.returns([0,1]) if @new_resource.ignore_failure && @new_resource.returns.nil?
          @new_resource.command("#{node['wp']['wpcli-bin']} #{@new_resource.command} #{args_str}");
          super
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

    end
  end
end
