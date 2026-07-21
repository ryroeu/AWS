#!/bin/bash
yum install httpd -y
yum update -y
echo "Hello World!" > /var/www/html/index.html
service httpd start
chkconfig httpd on
