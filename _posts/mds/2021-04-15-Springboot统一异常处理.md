---
layout: post
title: "Springboot统一异常处理"
# subtitle: ""
date: 2021-04-15 12:09:00
author: youthred
header-style: text
catalog: true
tags: [SpringBoot]
---

```java
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * 控制器全局异常处理
 *
 * @author pj.w@qq.com
 */
@ControllerAdvice
public class GlobalExceptionHandler {

    @ResponseBody
    @ExceptionHandler(Exception.class)
    public Object globalExceptionHandler(Exception e) {
        e.printStackTrace();
        return e.getMessage();
    }

    @ResponseBody
    @ExceptionHandler(MyE.class)
    public Object globalExceptionHandler(MyE e) {
        e.printStackTrace();
        return e.getMessage();
    }
}
```