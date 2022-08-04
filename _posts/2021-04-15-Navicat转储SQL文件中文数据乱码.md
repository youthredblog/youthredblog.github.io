---
layout: post
title: "Navicat转储SQL文中文数据乱码"
# subtitle: ""
date: 2021-04-15 11:04:28
author: youthred
header-img: "img/jk-siwa.png"
catalog: true
tags: [MySQL]
---

用Navicat转储SQL文件，中文数据会这样乱码

``` sql
-- ----------------------------
-- Records of sys_permission
-- ----------------------------
INSERT INTO `sys_permission` VALUES (1, 'admin:user', '/admin/user/**', '瀵圭敤鎴风殑鎵€鏈夋搷浣?);
INSERT INTO `sys_permission` VALUES (2, 'letter:save', '/letter/save', '娣诲姞letter');
INSERT INTO `sys_permission` VALUES (3, 'letter:delete', '/letter/delete/*', '鍒犻櫎letter');
INSERT INTO `sys_permission` VALUES (4, 'letter:update', '/letter/update/*', '鏇存柊letter');
INSERT INTO `sys_permission` VALUES (5, 'letter:find', '/letter/find/**', '鏌ユ壘letter锛屽寘鎷?find/{id}锛?find/pages锛岀瓑');
```

用Notepad2打开的.sql文件，依次点击【文件】【编码】【重新编码】，然后选择原数据库的编码格式即可，一般都是UTF-8的吧

![UTF-8](/img/for-post/005Ii7rngy1gcgyjj9x5oj30ad0ahmxb.jpg)