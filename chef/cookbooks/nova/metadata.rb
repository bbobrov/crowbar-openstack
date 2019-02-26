name "nova"
maintainer "Crowbar project"
maintainer_email "crowbar@googlegroups.com"
license "Apache 2.0"
description "Installs/Configures nova"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version "0.3"

depends "ceph"
depends "ses"
depends "crowbar-openstack"
depends "crowbar-pacemaker"
depends "database"
depends "ec2-api"
depends "keystone"
depends "memcached"
depends "neutron"
depends "utils"
