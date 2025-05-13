---
layout: post
title: "Elasticsearch7.6.x允许head-master跨域访问"
# subtitle: ""
date: 2021-04-15 19:22:00
author: youthred
header-img: "img/onepunch.png"
catalog: true
tags: [Elasticsearch]
---

修改`config/elasticsearch.yml`文件

``` yml
# 开启跨域
http.cors.enabled: true
# 允许所有
http.cors.allow-origin: "*"
```