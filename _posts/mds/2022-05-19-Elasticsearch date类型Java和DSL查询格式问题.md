---
layout: post
title: "Elasticsearch date类型Java和DSL查询格式问题"
subtitle: "在es里查询条件`date`类型的字段时，比如`range`查询，若格式化设为`yyyy-MM-dd HH:mm:ss`，则传入的`gte`等参数默认只接受这个格式的字符串。如果传入时间戳的`long`值，则需指定format为`epoch_millis`”，两种参数意义一样，只在形式不同，但其查询结果却不一致。"
date: 2022-05-19 10:01:00
author: youthred
header-style: text
catalog: true
tags: [Elasticsearch]
---

> ES版本6.7.1，Java rest-high-level-client版本6.7.2

在es里查询条件`date`类型的字段时，比如`range`查询，若格式化设为`yyyy-MM-dd HH:mm:ss`，则传入的`gte`等参数默认只接受这个格式的字符串。
如果传入时间戳的`long`值，则需指定format为`epoch_millis`”，两种参数意义一样，只在形式不同，但其查询结果却不一致。

- 字符串形式
```
GET es_demo/_count
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
            "createTime": {
              "gte": "2021-11-12 00:00:00",
              "lte": "2021-11-13 23:59:59"
            }
          }
        }
      ]
    }
  }
}
```

字符串时间参数统计结果
``` json
{
  "count": 1112,
  "_shards": {
    "total": 5,
    "successful": 5,
    "skipped": 0,
    "failed": 0
  }
}
```

- 时间戳long值形式
```
GET es_demo/_count
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
              "createTime": {
                "gte": "1636646400000",
                "lte": "1636819199000",
                "format": "epoch_millis"
              }
            }
        }
      ]
    }
  }
}
```

时间戳long值参数统计结果
``` json
{
  "count": 1580,
  "_shards": {
    "total": 5,
    "successful": 5,
    "skipped": 0,
    "failed": 0
  }
}
```

两者统计结果却并不一致。ES的时区并不能像一般的关系型数据库那样自动转换，所以接下来再在时间戳形式的`range`里加上`time_zone`属性，值设置为`+0800`。

```
GET es_demo/_count
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
              "createTime": {
                "gte": "1636646400000",
                "lte": "1636819199000",
                "format": "epoch_millis",
                "time_zone": "+0800"
              }
            }
        }
      ]
    }
  }
}
```

执行结果

``` json
{
  "error": {
    "root_cause": [
      {
        "type": "parse_exception",
        "reason": "failed to parse date field [1636646400000] with format [epoch_millis]"
      }
    ],
    "type": "search_phase_execution_exception",
    "reason": "all shards failed",
    "phase": "query",
    "grouped": true,
    "failed_shards": [
      {
        "shard": 0,
        "index": "es_demo",
        "node": "dmgSpYrDRGOAWTgwnxdyEw",
        "reason": {
          "type": "parse_exception",
          "reason": "failed to parse date field [1636646400000] with format [epoch_millis]",
          "caused_by": {
            "type": "illegal_argument_exception",
            "reason": "time_zone must be UTC for format [epoch_millis]"
          }
        }
      }
    ]
  },
  "status": 400
}
```

注意这句`time_zone must be UTC for format [epoch_millis]`，说明使用`epoch_millis`时的时区设置必须在`+0000`。

所以需要变个方式，在时间戳里加上8小时。

- 获取手动+0800(CST)的时间戳
``` java
@Slf4j
class EsTest {

    // time_zone must be UTC for format [epoch_millis] 使用epoch_millis格式查询date类型时需要加8小时

    @Test
    void plus8hByHand() {
        log.info("" + LocalDateTimeUtil.toEpochMilli(LocalDateTime.of(2021, 11, 12, 0, 0, 0).plusHours(8)));
        log.info("" + LocalDateTimeUtil.toEpochMilli(LocalDateTime.of(2021, 11, 13, 23, 59, 59).plusHours(8)));
    }
}
```

使用新时间戳参数DSL查询
```
GET es_demo/_count
{
  "query": {
    "bool": {
      "must": [
        {
          "range": {
              "createTime": {
                "gte": "1636675200000",
                "lte": "1636847999000",
                "format": "epoch_millis"
              }
            }
        }
      ]
    }
  }
}
```

执行结果

``` json
{
  "count": 1112,
  "_shards": {
    "total": 5,
    "successful": 5,
    "skipped": 0,
    "failed": 0
  }
}
```

此时结果一致。

- Java rest-high-level-client API 条件构造

```
QueryBuilders.rangeQuery("createTime")
    .gte(LocalDateTimeUtil.toEpochMilli(LocalDateTimeUtil.parse("2021-11-12 00:00:00", DatePattern.NORM_DATETIME_PATTERN).plusHours(8)))
    .lte(LocalDateTimeUtil.toEpochMilli(LocalDateTimeUtil.parse("2021-11-13 23:59:59", DatePattern.NORM_DATETIME_PATTERN).plusHours(8)))
    .format("epoch_millis")
```

---

文中出现的工具类来自hutool或apache.commons
