---
layout: post
title: "Oracle使用SQL语句添加序列"
# subtitle: ""
date: 2021-04-15 17:06:28
author: youthred
header-img: "img/onepunch.png"
catalog: true
tags: [Oracle]
---

``` sql
CREATE SEQUENCE SEQ_XXX
MINVALUE 1
NOMAXVALUE
INCREMENT BY 1
START WITH 1
CACHE 5;
```