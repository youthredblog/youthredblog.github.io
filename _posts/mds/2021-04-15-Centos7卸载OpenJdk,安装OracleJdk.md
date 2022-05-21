---
layout: post
title: "Centos7卸载OpenJdk,安装OracleJdk"
#subtitle: ""
date: 2021-04-15 13:23:00
author: youthred
header-style: text
catalog: true
tags: [CentOS,JDK]
---

### 查看JDK版本

``` shell
java -version
```

### 查找openjdk安装包
``` shell
rpm -qa | grep openjdk
```

### 卸载openjdk
``` shell
yum -y remove java*openjdk*
```

### 获取oraclejdk
- [oraclejdk11.0.9.rpm 提取码:0000](https://pan.baidu.com/s/1Lq7hUlJW2khRs0l1tfU_9w)
- 上传到服务器，若无rz/sz命令请先执行`yum install -y lrzsz`

### 本地安装RPM
``` shell
sudo yum localinstall jdk-11.0.9_linux-x64_bin.rpm
```

### 设置环境变量
- `vim /etc/profile`
- 末尾添加
``` shell
JAVA_HOME=/usr/java/jdk-11.0.9
PATH=$JAVA_HOME/bin:$PATH
CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export JAVA_HOME
export PATH
export CLASSPATH
```
- `source /etc/profile`

### 再次执行`java -version`查看当前Java版本
``` shell
java version "11.0.9" 2020-10-20 LTS
Java(TM) SE Runtime Environment 18.9 (build 11.0.9+7-LTS)
Java HotSpot(TM) 64-Bit Server VM 18.9 (build 11.0.9+7-LTS, mixed mode)
```

---

[如何在CentOS上安装RPM软件包](https://www.myfreax.com/how-to-install-rpm-packages-on-centos/)