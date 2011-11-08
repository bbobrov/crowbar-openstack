#
# Cookbook Name:: nova
# Recipe:: setup
#
# Copyright 2010-2011, Opscode, Inc.
# Copyright 2011, Anso Labs
# Copyright 2011, Dell, Inc.
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

include_recipe "nova::mysql"
include_recipe "nova::config"

execute "nova-manage db sync" do
  command "nova-manage db sync"
  action :run
end

execute "nova-manage network create --fixed_range_v4=#{node[:nova][:fixed_range]} --num_networks=#{node[:nova][:num_networks]} --network_size=#{node[:nova][:network_size]} --label nova_fixed --multi_host=T" do
  user node[:nova][:user]
  not_if "nova-manage network list | grep '#{node[:nova][:fixed_range]}'"
end

# Add private network one day.

execute "nova-manage floating create --ip_range=#{node[:nova][:floating_range]}" do
  user node[:nova][:user]
  not_if "nova-manage floating list | grep '#{node[:nova][:floating_range].split("/")[0]}'"
end

if node[:nova][:network_type] != "dhcpvlan"
  env_filter = " AND mysql_config_environment:mysql-config-#{node[:nova][:mysql_instance]}"
  db_server = search(:node, "roles:mysql-server#{env_filter}")[0]
  execute "mysql-fix-ranges-fixed" do
    command "/usr/bin/mysql -u #{node[:nova][:db][:user]} -h #{db_server[:mysql][:api_bind_host]} -p#{node[:nova][:db][:password]} #{node[:nova][:db][:database]} < /etc/mysql/nova-fixed-range.sql"
    action :nothing
  end

  fixed_net = node[:network][:networks]["nova_fixed"]
  rangeH = fixed_net["ranges"]["dhcp"]
  netmask = fixed_net["netmask"]
  subnet = fixed_net["subnet"]

  index = IPAddr.new(rangeH["start"]) & ~IPAddr.new(netmask)
  index = index.to_i
  stop_address = IPAddr.new(rangeH["end"]) & ~IPAddr.new(netmask)
  stop_address = IPAddr.new(subnet) | (stop_address.to_i + 1)
  address = IPAddr.new(subnet) | index

  network_list = []
  while address != stop_address
    network_list << address.to_s
    index = index + 1
    address = IPAddr.new(subnet) | index
  end
  network_list << address.to_s

  template "/etc/mysql/nova-fixed-range.sql" do
    path "/etc/mysql/nova-fixed-range.sql"
    source "fixed-range.sql.erb"
    owner "root"
    group "root"
    mode "0600"
    variables(
      :network => network_list
    )
    notifies :run, resources(:execute => "mysql-fix-ranges-fixed"), :immediately
  end
end

