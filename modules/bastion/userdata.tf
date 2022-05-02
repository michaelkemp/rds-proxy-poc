
locals {
  userdata = <<-USERDATA
    #!/bin/bash

    ## Install Postgres13
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

    sudo tee /home/ec2-user/create-db.sql<<EOF
    CREATE DATABASE testdb;
    CREATE USER testuser with encrypted password '${var.testdb_pwd}';
    grant all privileges on database testdb to testuser;
    EOF

    sudo tee /home/ec2-user/create-table.sql<<EOF
    CREATE TABLE people (
    id BIGSERIAL,
    fullname TEXT,
    gender TEXT,
    phone TEXT,
    age INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
    );
    EOF

  USERDATA
}
