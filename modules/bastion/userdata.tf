
locals {
  userdata = <<-USERDATA
    #!/bin/bash
    sudo tee /etc/yum.repos.d/pgdg.repo<<EOF
    [pgdg13]
    name=PostgreSQL 13 for RHEL/CentOS 7 - x86_64
    baseurl=https://download.postgresql.org/pub/repos/yum/13/redhat/rhel-7-x86_64
    enabled=1
    gpgcheck=0
    EOF
    sudo yum -y update
    sudo yum -y upgrade
    sudo yum install postgresql13 -y
  USERDATA
}
