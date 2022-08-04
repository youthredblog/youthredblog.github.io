---
layout: post
title: "SpringBoot @PropertySource自定义配置yml文件"
subtitle: "有时候同一类配置需要单独使用一个配置文件，这个注解`@PropertySource`可以简单快速的实现。"
date: 2022-05-20 14:15:00
author: youthred
header-img: "img/jk-siwa.png"
catalog: true
tags: [SpringBoot]
---

有时候同一类配置需要单独使用一个配置文件，这个注解`@PropertySource`可以简单快速的实现。

```
@PropertySource(value = {"classpath:custom.properties"})
```

对于`YAML`格式也是可以解析的，但需要实现`PropertySourceFactory`。

``` java
package com.fritt.es.cleaner.conf;

import org.springframework.beans.factory.config.YamlPropertiesFactoryBean;
import org.springframework.core.env.PropertiesPropertySource;
import org.springframework.core.env.PropertySource;
import org.springframework.core.io.support.EncodedResource;
import org.springframework.core.io.support.PropertySourceFactory;

import java.io.IOException;
import java.util.Objects;

public class YamlPropertySourceFactory implements PropertySourceFactory {

    @Override
    public PropertySource<?> createPropertySource(String s, EncodedResource encodedResource) throws IOException {
        YamlPropertiesFactoryBean factoryBean = new YamlPropertiesFactoryBean();
        factoryBean.setResources(encodedResource.getResource());
        return new PropertiesPropertySource(encodedResource.getResource().getFilename(), Objects.requireNonNull(factoryBean.getObject()));
    }
}
```

然后在注解上指明。

```
@PropertySource(
    factory = YamlPropertySourceFactory.class,
    value = {"classpath:custom.yml"}
)
```

建议再加上注解`@ConfigurationProperties(prefix = "conf")`指明前缀，不建议使用`org.springframework.beans.factory.annotation.Value`来绑定配置。

配置文件就是拿来修改的，以上的自定义配置在打包后便难以更改，好在该注解的`value`属性还提供了另一种路径解析方式`file`。

在项目根目录`与src平级`上新增目录`config`，移入自定义配置文件，修改`value`属性值自定义配置路径。

```
value = {"file:./config/custom.yml"}
```

再次打包，新建jar包的平级目录`config`，放入自定义配置文件，这样更改后的配置无需重新打包即可生效。

---

SpringBoot的配置读取优先顺序（优先级递减）为：

1. 根目录下`config`

2. 根目录

3. `classpath`下`config`

4. `classpath`

*且`.properties`的优先级大于`.yml`*
