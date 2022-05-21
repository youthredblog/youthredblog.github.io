---
layout: post
title: "MySQL集合查询all_elements_are_null"
# subtitle: ""
date: 2021-04-26 11:04:28
author: youthred
header-style: text
catalog: true
tags: [MySQL]
---

今天用CollectionUtils判断集合是否为空时发现个奇怪的查询数据：集合size=1，展开后提示“all elements are null”，SQL单独查询是空的。
就很奇怪，为什么SQL查出来一条都没有但代码里size=1还all elements are null。

Google了一下，都是说映射字段名称的问题，都试过也不对。

我这里的数据库是MySQL8，中间件是MyBatisPlus3.4.2，查询SQL为：
``` sql
select
  r.tb_id,
  r.role_code,
  r.role_name,
  r.role_desc
from t_sys_user u
left join t_sys_bind_user_role ur on ur.user_tb_id = u.tb_id
left join t_sys_role r on r.tb_id = ur.role_tb_id
where u.tb_id = #{sysUserTbId}
```
用户、角色和中间表分别为：

用户

| tb_id | username | password                         | nickname | email        | enabled | create_time         | update_time         |
| ----- | -------- | -------------------------------- | -------- | ------------ | ------- | ------------------- | ------------------- |
| 1     | admin    | 21232f297a57a5a743894a0e4a801fc3 | 张三     | admin@qq.com | 1       | 2020-12-13 00:09:54 | 2021-04-24 13:49:04 |
| 2     | jack     | 4ff9fc6e4e5d5f590c4f2134a8cc96d1 | 李四     | jack@qq.com  | 1       | 2020-12-13 00:11:39 | 2021-04-24 14:02:25 |
| 14    | rose     | fcdc7b4207660a1372d0cd5491ad856e | rose     | rose@qq.com  | 1       | 2021-04-25 17:33:04 | 2021-04-25 18:32:48 |

角色

| tb_id | role_code         | role_name | role_desc |
| ----- | ----------------- | --------- | --------- |
| 1     | ADMIN             | 管理员    |           |
| 2     | MEMBER_REGISTERED | 注册会员  |           |

用户角色中间表

| user_tb_id | role_tb_id |
| ---------- | ---------- |
| 1          | 1          |
| 2          | 1          |

目的是通过用户ID查找对应的角色信息，但问题就出在这里：此时的中间表里没有ROSE的角色信息，那么改一改SQL：

``` sql
select
  u.username, -- 新增查询用户名
  r.tb_id,
  r.role_code,
  r.role_name,
  r.role_desc
from t_sys_user u
left join t_sys_bind_user_role ur on ur.user_tb_id = u.tb_id
left join t_sys_role r on r.tb_id = ur.role_tb_id
-- 去掉ID筛选
```

结果：

| username | tb_id | role_code         | role_name | role_desc |
| -------- | ----- | ----------------- | --------- | --------- |
| admin    | 1     | ADMIN             | 管理员    |           |
| jack     | 2     | MEMBER_REGISTERED | 注册会员  |           |
| rose     |       |                   |           |           |

可以看到角色部分都为空，但用户部分是有数据的，但按理说只选了角色表自动进行查询，应该一条都查不到，代码里也应该size=0，平时在公司用的Oracle还没碰到这个问题。

那么假设就是因为这个原因，则SQL里就需要添加不为空筛选了，修改SQL如下：

``` sql
select
    r.tb_id,
    r.role_code,
    r.role_name,
    r.role_desc
from t_sys_user u
left join t_sys_bind_user_role ur on ur.user_tb_id = u.tb_id
left join t_sys_role r on r.tb_id = ur.role_tb_id
where r.tb_id is not null -- 添加了不为空筛选
and u.tb_id = #{sysUserTbId}
```

DEBUG项目，size=0，问题解决。