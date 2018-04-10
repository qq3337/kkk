#!/bin/bash
yum -y install epel-release
yum -y install nginx
yum -y install php-fpm
iptables -n -L INPUT|grep ACCEPT|grep 443
if [ $? -eq "1" ] 
then
	iptables -I INPUT 1 -m state --state NEW -p tcp --dport 443 -j ACCEPT
	service iptables save
fi
service php-fpm start
service nginx start