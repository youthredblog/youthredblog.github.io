---
layout: post
title: "Logback自定义过滤器实现日志的WebSocket前端输出"
#subtitle: ""
date: 2022-05-23 13:36:39
author: youthred
header-img: "img/jk-siwa.png"
catalog: true
tags: [SpringBoot,Java,Logback]
---

> 自定义实现WebSocket前端日志输出，最开始想的是读日志文件，但这样太不优雅，操作文件尤其是日志文件的效率又很低。所以找到了`ch.qos.logback.core.filter.Filter`。

## 实现WebSocket服务端

### Netty服务端 WsSer

``` java
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class WsSer implements ApplicationRunner {

    @Override
    public void run(ApplicationArguments args) throws Exception {
        EventLoopGroup bossGroup = new NioEventLoopGroup();
        EventLoopGroup workerGroup = new NioEventLoopGroup();
        try {
            // 正式环境中建议从配置文件读取
            final int port = 3333;
            ServerBootstrap sb = new ServerBootstrap();
            sb.option(ChannelOption.SO_BACKLOG, 1024);
            sb.group(workerGroup, bossGroup)
                    .channel(NioServerSocketChannel.class)
                    .localAddress(port)
                    .childHandler(new SocketChannelInitializer());
            ChannelFuture cf = sb.bind(port).sync();
            cf.channel().closeFuture().sync();
        } finally {
            workerGroup.shutdownGracefully().sync();
            bossGroup.shutdownGracefully().sync();
        }
    }
}
```

### SocketChannelInitializer

``` java
import io.github.youthred.es.cleaner.conf.netty.handler.ConnectHandler;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.socket.SocketChannel;
import io.netty.handler.codec.http.HttpObjectAggregator;
import io.netty.handler.codec.http.HttpServerCodec;
import io.netty.handler.codec.http.websocketx.WebSocketServerProtocolHandler;
import io.netty.handler.stream.ChunkedWriteHandler;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class SocketChannelInitializer extends ChannelInitializer<SocketChannel> {

    @Override
    protected void initChannel(SocketChannel socketChannel) throws Exception {
        socketChannel.pipeline()
                .addLast(new HttpServerCodec())
                .addLast(new ChunkedWriteHandler())
                .addLast(new HttpObjectAggregator(8092))
                .addLast(new WebSocketServerProtocolHandler("/ws", "WebSocket", true, 65536 * 10))
                .addLast(new ConnectHandler())
        ;
    }
}
```

### 客户端InboundHandler ConnectHandler

``` java
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInboundHandlerAdapter;
import io.netty.channel.group.ChannelGroup;
import io.netty.channel.group.DefaultChannelGroup;
import io.netty.handler.codec.http.websocketx.TextWebSocketFrame;
import io.netty.util.concurrent.GlobalEventExecutor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class ConnectHandler extends ChannelInboundHandlerAdapter {

    private static final ChannelGroup CHANNEL_GROUP = new DefaultChannelGroup(GlobalEventExecutor.INSTANCE);

    @Override
    public void channelActive(ChannelHandlerContext ctx) throws Exception {
        log.info("Channel Active: {}", ctx.channel().remoteAddress().toString());
        CHANNEL_GROUP.add(ctx.channel());
    }

    @Override
    public void channelInactive(ChannelHandlerContext ctx) throws Exception {
        log.info("Channel Inactive: {}", ctx.channel().remoteAddress().toString());
        CHANNEL_GROUP.remove(ctx.channel());
    }

    /**
     * 广播
     * 
     * @param message 广播内容
     */
    public static void broadcast(String message) {
        CHANNEL_GROUP.writeAndFlush(new TextWebSocketFrame(message));
    }
}
```

## 自定义日志过滤器

### WsLogFilter

``` java
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.filter.Filter;
import ch.qos.logback.core.spi.FilterReply;
import cn.hutool.core.date.DatePattern;
import cn.hutool.core.date.LocalDateTimeUtil;
import cn.hutool.core.util.StrUtil;
import io.github.youthred.es.cleaner.conf.netty.handler.ConnectHandler;
import lombok.extern.slf4j.Slf4j;

import java.time.format.DateTimeFormatter;

@Slf4j
public class WsLogFilter extends Filter {

    @Override
    public FilterReply decide(Object o) {
        ILoggingEvent e = (ILoggingEvent) o;
        String format = StrUtil.format("{} - {} - {}: {}",
                e.getLevel().levelStr,
                LocalDateTimeUtil.of(e.getTimeStamp()).format(DateTimeFormatter.ofPattern(DatePattern.NORM_DATETIME_PATTERN)),
                e.getLoggerName(),
                e.getMessage());
        // 广播发送
        ConnectHandler.broadcast(format);
        return FilterReply.ACCEPT;
    }
}
```

### 在logback配置中加入自定义过滤器

在SpringBoot中默认配置文件是 `logback-spring.xml`

``` xml
<?xml version="1.0" encoding="UTF-8" ?>
<configuration>
    <property name="log.charset" value="UTF-8"/>
    <property name="log.pattern"
              value="${CONSOLE_LOG_PATTERN:-%clr(${LOG_LEVEL_PATTERN:-%p})-%clr(%d{yyyy-MM-dd HH:mm:ss}){faint}-%clr([%thread]){magenta}-%clr(%logger{40}){cyan}:%msg%n${LOG_EXCEPTION_CONVERSION_WORD:-%wEx}}"/>
    <!-- 彩色日志转换配置 -->
    <conversionRule conversionWord="clr"
                    converterClass="org.springframework.boot.logging.logback.ColorConverter"/>
    <conversionRule conversionWord="wex"
                    converterClass="org.springframework.boot.logging.logback.WhitespaceThrowableProxyConverter"/>
    <conversionRule conversionWord="wEx"
                    converterClass="org.springframework.boot.logging.logback.ExtendedWhitespaceThrowableProxyConverter"/>
    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <!-- 自定义过滤器 -->
        <filter class="x.x.x.WsLogFilter"/>
        <encoder>
            <pattern>${log.pattern}</pattern>
        </encoder>
    </appender>
    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
    </root>
</configuration>
```

## 前端代码

``` html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>WS-LOG</title>
</head>
<body>
<script type="text/javascript">
    let socket
    if (!window.WebSocket) {
        window.WebSocket = window.MozWebScoket
    }
    if (window.WebSocket) {
        const host = 'ws://[换成具体IP，不建议使用localhost，localhost在非本地客户端无法连接]:3333/ws'
        socket = new WebSocket(host)
        socket.onmessage = (e) => console.log(e.data)
        socket.onopen = (e) => console.log(`Connected to ${host}`)
        socket.onclose = (e) => console.log(`Connect closed`)
    } else {
        console.log('浏览器不支持WebSocket')
    }
</script>
</body>
</html>
```

## 测试

## 在后台写一个定时日志日期打印

``` java
// cn.hutool.cron.CronUtil
CronUtil.schedule("*/1 * * * * *", (Task) () -> log.info(LocalDateTime.now().format(DateTimeFormatter.ofPattern(DatePattern.NORM_DATETIME_PATTERN))));
CronUtil.setMatchSecond(true);
CronUtil.start();
```

## Chrome控制台输出

*IP脱敏*

```
Connected to ws://x.x.x.x:3333/ws
INFO - 2022-05-23 14:17:04 - io.github.youthred.es.cleaner.conf.Init: 2022-05-23 14:17:04
INFO - 2022-05-23 14:17:05 - io.github.youthred.es.cleaner.conf.Init: 2022-05-23 14:17:05
INFO - 2022-05-23 14:17:06 - io.github.youthred.es.cleaner.conf.Init: 2022-05-23 14:17:06
INFO - 2022-05-23 14:17:07 - io.github.youthred.es.cleaner.conf.Init: 2022-05-23 14:17:07
INFO - 2022-05-23 14:17:08 - io.github.youthred.es.cleaner.conf.Init: 2022-05-23 14:17:08
INFO - 2022-05-23 14:17:09 - io.github.youthred.es.cleaner.conf.Init: 2022-05-23 14:17:09
INFO - 2022-05-23 14:17:10 - io.github.youthred.es.cleaner.conf.Init: 2022-05-23 14:17:10
INFO - 2022-05-23 14:17:10 - org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor: Shutting down ExecutorService 'applicationTaskExecutor'
Connect closed
```

---

简单实现了后台日志使用WebSocket前端输出，只此记录。实际项目还需加倍完善。
