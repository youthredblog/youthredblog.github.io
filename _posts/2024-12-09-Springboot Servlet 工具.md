---
layout: post
title: "Springboot Servlet 工具"
# subtitle: ""
date: 2024-12-09 18:33:00
author: youthred
header-img: "img/jk-siwa.png"
catalog: true
tags: [Java,Springboot]
---

```java
package spring.util;

import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import javax.servlet.http.HttpServletRequest;
import java.util.Objects;

public class HttpServletUtil {

    /**
     * 在Springboot项目中任务位置获取当前访问Session的HttpServletRequest对象
     *
     * @return HttpServletRequest
     */
    public static HttpServletRequest getHttpServletRequest() {
        RequestAttributes requestAttributes = RequestContextHolder.getRequestAttributes();
        if (Objects.nonNull(requestAttributes)) {
            return ((ServletRequestAttributes) requestAttributes).getRequest();
        }
        return null;
    }
}

```

