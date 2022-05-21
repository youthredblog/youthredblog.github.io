---
layout: post
title: "Centos7下MySQL8彻底卸载及安装"
# subtitle: ""
date: 2021-04-15 00:00:00
author: youthred
header-style: text
catalog: true
tags: [CentOS,MySQL]
---

## 首先升级yum `yum update`

## 查看已安装的MySQL

``` shell
[root@centos7 ~]# rpm -qa | grep -i mysql
mysql80-community-release-el7-3.noarch
mysql-community-client-8.0.22-1.el7.x86_64
mysql-community-common-8.0.22-1.el7.x86_64
mysql-community-server-8.0.22-1.el7.x86_64
mysql-community-client-plugins-8.0.22-1.el7.x86_64
mysql-community-libs-8.0.22-1.el7.x86_64
```

## 卸载

``` shell
[root@centos7 ~]# yum remove -y mysql*
Loaded plugins: fastestmirror, product-id, search-disabled-repos, subscription-manager

This system is not registered with an entitlement server. You can use subscription-manager to register.

No Match for argument: mysql80-community-release-el7-3.noarch.rpm
No Packages marked for removal
```

有可能碰到上面所示的提示，此时先卸载“mysql80-community-release-el7-3.noarch”

``` shell
[root@centos7 ~]# yum -y remove mysql80-community-release-el7-3.noarch
Loaded plugins: fastestmirror, product-id, search-disabled-repos, subscription-manager

This system is not registered with an entitlement server. You can use subscription-manager to register.

Resolving Dependencies
--> Running transaction check
---> Package mysql80-community-release.noarch 0:el7-3 will be erased
--> Finished Dependency Resolution

Dependencies Resolved

============================================================================================================================================================================================================================================================================================================================================
 Package                                                                                        Arch                                                                        Version                                                                    Repository                                                                      Size
============================================================================================================================================================================================================================================================================================================================================
Removing:
 mysql80-community-release                                                                      noarch                                                                      el7-3                                                                      installed                                                                       31 k

Transaction Summary
============================================================================================================================================================================================================================================================================================================================================
Remove  1 Package

Installed size: 31 k
Downloading packages:
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Erasing    : mysql80-community-release-el7-3.noarch                                                                                                                                                                                                                                                                                   1/1 
  Verifying  : mysql80-community-release-el7-3.noarch                                                                                                                                                                                                                                                                                   1/1 

Removed:
  mysql80-community-release.noarch 0:el7-3                                                                                                                                                                                                                                                                                                  

Complete!

```

再卸载其他

``` shell
[root@centos7 ~]# yum -y remove mysql-*
Loaded plugins: fastestmirror, product-id, search-disabled-repos, subscription-manager

This system is not registered with an entitlement server. You can use subscription-manager to register.

Resolving Dependencies
--> Running transaction check
---> Package mysql-community-client.x86_64 0:8.0.22-1.el7 will be erased
---> Package mysql-community-client-plugins.x86_64 0:8.0.22-1.el7 will be erased
---> Package mysql-community-common.x86_64 0:8.0.22-1.el7 will be erased
---> Package mysql-community-libs.x86_64 0:8.0.22-1.el7 will be erased
---> Package mysql-community-server.x86_64 0:8.0.22-1.el7 will be erased
--> Finished Dependency Resolution

Dependencies Resolved

============================================================================================================================================================================================================================================================================================================================================
 Package                                                                                       Arch                                                                  Version                                                                        Repository                                                                         Size
============================================================================================================================================================================================================================================================================================================================================
Removing:
 mysql-community-client                                                                        x86_64                                                                8.0.22-1.el7                                                                   @mysql80-community                                                                230 M
 mysql-community-client-plugins                                                                x86_64                                                                8.0.22-1.el7                                                                   @mysql80-community                                                                1.0 M
 mysql-community-common                                                                        x86_64                                                                8.0.22-1.el7                                                                   @mysql80-community                                                                8.9 M
 mysql-community-libs                                                                          x86_64                                                                8.0.22-1.el7                                                                   @mysql80-community                                                                 22 M
 mysql-community-server                                                                        x86_64                                                                8.0.22-1.el7                                                                   @mysql80-community                                                                2.3 G

Transaction Summary
============================================================================================================================================================================================================================================================================================================================================
Remove  5 Packages

Installed size: 2.6 G
Downloading packages:
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Erasing    : mysql-community-server-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                               1/5 
  Erasing    : mysql-community-client-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                               2/5 
  Erasing    : mysql-community-libs-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                                 3/5 
  Erasing    : mysql-community-common-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                               4/5 
  Erasing    : mysql-community-client-plugins-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                       5/5 
  Verifying  : mysql-community-client-plugins-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                       1/5 
  Verifying  : mysql-community-common-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                               2/5 
  Verifying  : mysql-community-client-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                               3/5 
  Verifying  : mysql-community-libs-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                                 4/5 
  Verifying  : mysql-community-server-8.0.22-1.el7.x86_64                                                                                                                                                                                                                                                                               5/5 

Removed:
  mysql-community-client.x86_64 0:8.0.22-1.el7                     mysql-community-client-plugins.x86_64 0:8.0.22-1.el7                     mysql-community-common.x86_64 0:8.0.22-1.el7                     mysql-community-libs.x86_64 0:8.0.22-1.el7                     mysql-community-server.x86_64 0:8.0.22-1.el7                    

Complete!
```

删除剩余的MySQL相关文件和文件夹

``` shell
[root@centos7 ~]# find / -name mysql
```

## 重新安装

CentOS7好像没有MySQL的源，取而代之是内部集成的MariaDB。[官网下载](https://dev.mysql.com/downloads/repo/yum/)MySQL的RPM源，安装成功后会自动覆盖MariaDB。下载完成后上传到服务器。

``` shell
-rw-r--r-- 1 root root 26024 Jan  3 17:46 mysql80-community-release-el7-3.noarch.rpm
```

### 安装repo并更新yum缓存

``` shell
rpm -ivh mysql80-community-release-el7-3.noarch.rpm
```

执行后会在`/etc/yum.repos.d/`下生成两个repo文件

``` shell
[root@centos7 ~]# ll /etc/yum.repos.d/ | grep mysql
-rw-r--r-- 1 root root 2076 Apr 25  2019 mysql-community.repo
-rw-r--r-- 1 root root 2108 Apr 25  2019 mysql-community-source.repo
```

### 刷新yum

``` shell
yum clean all | yum makecache
```

### 查看yum中的MySQL版本

``` shell
[root@centos7 ~]# yum repolist all | grep mysql
mysql-cluster-7.5-community/x86_64        MySQL Cluster 7.5 Comm disabled
mysql-cluster-7.5-community-source        MySQL Cluster 7.5 Comm disabled
mysql-cluster-7.6-community/x86_64        MySQL Cluster 7.6 Comm disabled
mysql-cluster-7.6-community-source        MySQL Cluster 7.6 Comm disabled
mysql-cluster-8.0-community/x86_64        MySQL Cluster 8.0 Comm disabled
mysql-cluster-8.0-community-source        MySQL Cluster 8.0 Comm disabled
mysql-connectors-community/x86_64         MySQL Connectors Commu enabled:    175
mysql-connectors-community-source         MySQL Connectors Commu disabled
mysql-tools-community/x86_64              MySQL Tools Community  enabled:    120
mysql-tools-community-source              MySQL Tools Community  disabled
mysql-tools-preview/x86_64                MySQL Tools Preview    disabled
mysql-tools-preview-source                MySQL Tools Preview -  disabled
mysql55-community/x86_64                  MySQL 5.5 Community Se disabled
mysql55-community-source                  MySQL 5.5 Community Se disabled
mysql56-community/x86_64                  MySQL 5.6 Community Se disabled
mysql56-community-source                  MySQL 5.6 Community Se disabled
mysql57-community/x86_64                  MySQL 5.7 Community Se disabled
mysql57-community-source                  MySQL 5.7 Community Se disabled
mysql80-community/x86_64                  MySQL 8.0 Community Se enabled:    211
mysql80-community-source                  MySQL 8.0 Community Se disabled
```

MySQL8已启用

可用命令`yum-config-manager --disable mysql80-community`或`yum-config-manager --enable mysql80-community`管理状态

或直接编辑`/etc/yum.repos.d/mysql-community.repo`

### 开始安装MySQL

``` shell
yum -y install mysql-community-server
```

完成后开启服务

``` shell
systemctl start mysqld
```

设置开机自启

``` shell
systemctl enable mysqld
```

### 登录MySQL

查看初始密码

``` shell
[root@centos7 ~]# grep 'temporary password' /var/log/mysqld.log 
2021-01-03T09:56:56.709802Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: Mu6Vr.s1EwsB
```

登录

``` shell
mysql -uroot -pMu6Vr.s1EwsB
```

修改密码

```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'custom-password';
```

若要远程连接

``` sql
-- 创建一个可以远程登陆的root用户
CREATE USER 'jojo'@'%' IDENTIFIED WITH mysql_native_password BY 'CUSTOM-PASSWORD';
```

``` sql
--- 为账户开放权限
grant all privileges on *.* to 'jojo'@'%';
flush privileges;
```

## 放行端口

### 使用CentOS7默认的firewall

开启firewalld

``` shell
systemctl start firewalld | systemctl enable firewalld
```

永久开放端口3306

``` shell
firewall-cmd --permanent --zone=public --add-port=3306/tcp
```

重新加载使之生效

``` shell
firewall-cmd --reload
```

查看当前开放的端口

```  shell
firewall-cmd --permanent --zone=public --list-ports
```

### 或者使用iptables

关闭firewalld服务

``` shell
systemctl stop firewalld | systemctl disable firewalld | systemctl mask firewalld
```

没有安装iptables之前`/etc/sysconfig/`下是没有`iptables`文件的，所有要先安装iptables

``` shell
yum -y install iptables-services
```

启动iptables服务

``` shell
systemctl enable iptables | systemctl start iptables
```

推荐直接`vim`编辑`/etc/sysconfig/iptables`

``` shell
# sample configuration for iptables service
# you can edit this manually or use system-config-firewall
# please do not ask us to add additional ports/services to this default configuration
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 3306 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 3389 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 1000 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
```

重启iptables

``` shell
systemctl restart iptables
```

