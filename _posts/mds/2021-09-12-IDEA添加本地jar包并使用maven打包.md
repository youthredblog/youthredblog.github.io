---
layout:     post
title:      "IDEA添加本地jar包并使用maven打包"
subtitle:   "如何在IDEA引入了本地jar包的情况下使用maven插件打包"
date:       2021-09-12 19:51:39
author:     "youthred"
header-style: text
catalog: true
tags: [IDEA,JAR]
---

之前写过一篇，今天记录另一种更简洁的，**如何在IDEA引入了本地jar包的情况下使用maven插件打包**

## 打开`Project Structure`

选择本地jar包所在目录并确认应用，这里我在当前项目下新建了名为lib的Directory，本地jar包都移到这里面

![select lib](https://wx2.sinaimg.cn/large/005Ii7rngy1gocuhg184bj30sw0noaaz.jpg)
![select lib](http://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Unix_timeline.en.svg/800px-Unix_timeline.en.svg.png)

完成后就可以看见已经成功引入本地jar包

![](https://wx3.sinaimg.cn/large/005Ii7rngy1gocuhznvibj30sw0nomxl.jpg)

然后转到Modules

![modules](https://wx1.sinaimg.cn/large/005Ii7rngy1goculwhb6oj30sw0not9e.jpg)

可以看到当前模块的依赖就有了刚刚添加的本地jar包，作用域为Compile

## pom.xml配置

打开侧栏`Project`的`External Libraries`，可以看到现在项目除了JDK以外并无其他依赖包

![`External Libraries`](https://wx1.sinaimg.cn/large/005Ii7rngy1gocurl0fbfj30e9099aa4.jpg)

打开`pom.xml`文件

正常的`Properties`

``` xml
<properties>
    <java.version>11</java.version>
</properties>
```

`dependencies`主要变化

```xml
<dependencies>
    <dependency>
        <groupId>lib</groupId>
        <artifactId>commons-lang3</artifactId>
        <version>3.11</version>
        <scope>system</scope>
        <systemPath>${project.basedir}/lib/commons-lang3-3.11.jar</systemPath>
    </dependency>
</dependencies>
```

此时`External Libraries`里也正常引入了

![](https://wx3.sinaimg.cn/large/005Ii7rngy1gocvej3sytj30ea0bkaa8.jpg)

然后是`build`

```xml
<build>
    <finalName>local-jar-dem</finalName>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
            <!-- 本地jar包还需要引入相关的springboot依赖，且版本号不可胜，得显式写出 -->
            <version>2.4.1</version>
            <configuration>
                <includeSystemScope>true</includeSystemScope>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <!-- 加上这个配置才能完成打包，不然打出来只有几十K -->
                        <goal>repackage</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
        <plugin>
            <!--
                这个配置是指定项目语言等级（解决刷新maven后lambda的支持问题），公司项目使用的Springboot为1.52，最高只支持Java6。
                当然，我这里的演示项目使用的当前最新版的Springboot2.4.1，安装的Java版本为JDK11，所以这个插件配置我这里可以不需要。
            -->
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>3.8.1</version>
            <configuration>
                <source>11</source>
                <target>11</target>
                <encoding>UTF-8</encoding>
            </configuration>
        </plugin>
    </plugins>
</build>
```

**此时就可以愉快地使用maven插件打包了 :)**

![奇迹再现](https://wx2.sinaimg.cn/large/005Ii7rngy1gocvh43u8ij30fx0a4jrg.jpg)

顺便一提，如果要使用IDEA Artifacts打包，需要注意的是在选择`MANIFEST.MF`文件保存位置时不要默认选到`xx/src/main/java`，这会导致打出来的包丢失主类信息如`Main-Class: net.add1s.localjardemo.LocalJarDemoApplication`