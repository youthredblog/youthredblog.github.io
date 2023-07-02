---
layout: post
title: "使事务注解@Transactional和MybatisPlus的@DS多数据源切换同时生效"
#subtitle: ""
date: 2022-06-08 10:21:00
author: youthred
header-img: img/jk-siwa.png
catalog: true
tags: [Java,MybatisPlus,Springboot]
---

之前做项目的时候使用`MyBatisPlus`的多数据源`dynamic-datasource-spring-boot-starter`，发现无法使事务`@Transactional`和多数据源`@DS`注解同时生效。

查阅文档后得知须在事务注解上指定事务传播方式:

``` java
// org.springframework.transaction.annotation.Transactional
@Transactional(
    rollbackFor = Exception.class,
    propagation = Propagation.REQUIRES_NEW  // 改变事务的传播方式
)
```