#
# Cookbook Name:: wpcli
# Resource:: wpcli
#

default_action :run
actions :run, :setup

attribute :path, :kind_of => String
attribute :command, :kind_of => String
attribute :code, :kind_of => String
attribute :args, :kind_of => Hash