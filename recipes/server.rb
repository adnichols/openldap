#
# Cookbook Name:: openldap
# Recipe:: server
#
# Copyright 2008-2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
include_recipe "openldap::client"

case node['platform']
when "ubuntu"

  package "db4.8-util" do
    action :upgrade
  end
  directory "/var/cache/local/preseeding" do
    mode 0755
    recursive true
  end
  cookbook_file "/var/cache/local/preseeding/slapd.seed" do
    source "slapd.seed"
    mode 00600
    owner "root"
    group "root"
  end
  package "slapd" do
    response_file "slapd.seed"
    action :upgrade
  end

when "centos"

  package "db4-utils" do
    action :upgrade
  end
  package "openldap-servers" do
    action :upgrade
  end
end



cookbook_file "#{node['openldap']['ssl_dir']}/#{node['openldap']['server']}.pem" do
  source "ssl/#{node['openldap']['server']}.pem"
  mode 00644
  owner "root"
  group "root"
end

service "slapd" do
  action [:enable, :start]
end



case node['platform']
when "debian","ubuntu"
  template "/etc/default/slapd" do
    source "default_slapd.erb"
    owner "root"
    group "root"
    mode 00644
  end

  directory "#{node['openldap']['dir']}/slapd.d" do
    recursive true
    owner "openldap"
    group "openldap"
    action :create
  end

  execute "slapd-config-convert" do
    command "slaptest -f #{node['openldap']['dir']}/slapd.conf -F #{node['openldap']['dir']}/slapd.d/"
    user "openldap"
    action :nothing
    notifies :start, "service[slapd]", :immediately
  end

  template "#{node['openldap']['dir']}/slapd.conf" do
    source "slapd.conf.erb"
    mode 00640
    owner "openldap"
    group "openldap"
    notifies :stop, "service[slapd]", :immediately
    notifies :run, "execute[slapd-config-convert]"
  end
  
  template "/root/base.ldif" do
    source "base.ldif.erb"
    mode 00640
    owner "openldap"
    group "openldap"
  end  


when "centos"
  template "/etc/default/slapd" do
    source "default_slapd.erb"
    owner "root"
    group "root"
    mode 00644
  end

  ################################################################
  #BUG IN YUM REPO: already has core in cn=schema,
  # so need to wipe slapd.d and start over only on first run
  #
  #Delete the old slapd.d directory because of duplication issues
  directory "#{node['openldap']['dir']}/slapd.d" do
    recursive true
    action :delete
    notifies :create, "ruby_block[first_run_wipe_slapd]", :immediately
    not_if { node.attribute?("first_run_wipe_slapd_complete") }
  end
  ruby_block "first_run_wipe_slapd" do
    block do
      node.set['first_run_wipe_slapd_complete'] = true
      node.save
    end
    action :nothing
  end
  ##############################################################

  directory "#{node['openldap']['dir']}/slapd.d" do
    recursive true
    owner "ldap"
    group "ldap"
    action :create
  end

  execute "slapd-config-convert" do
    command "slaptest -f #{node['openldap']['dir']}/slapd.conf -F #{node['openldap']['dir']}/slapd.d/"
    user "ldap"
    action :nothing
    notifies :start, "service[slapd]", :immediately
  end

  template "#{node['openldap']['dir']}/ldap.conf" do
    source "ldap-ldap.conf.erb"
    mode 00640
    owner "ldap"
    group "ldap"
  end  

  template "#{node['openldap']['dir']}/slapd.conf" do
    source "slapd.conf.erb"
    mode 00640
    owner "ldap"
    group "ldap"
    notifies :stop, "service[slapd]", :immediately
    notifies :run, "execute[slapd-config-convert]"
  end

  template "/root/base.ldif" do
    source "base.ldif.erb"
    mode 00640
    owner "ldap"
    group "ldap"
  end  

end



