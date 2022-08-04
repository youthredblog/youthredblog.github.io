---
layout: post
title: "SpringBoot下的异步线程池"
# subtitle: ""
date: 2021-04-15 22:32:28
author: youthred
header-img: "img/jk-siwa.png"
catalog: true
tags: [SpringBoot]
---

``` java
package net.add1s.config.thread;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.ThreadPoolExecutor;

/**
 * 须在启动类上添加注解“@EnableAsync”
 * 执行线程的方法必须被Spring容器管理，且不能使用“static”修饰，如在@Service修饰的实现类的方法上添加注解“@Async("taskExecutor")”后就可以正常使用异步线程
 * 执行异步线程的方法不能与调用方法同类
 *
 * @author pj.w@qq.com
 */
@Configuration
@EnableAsync
public class ThreadPoolTaskConfig {

    /**
     * 核心（默认）线程数
     */
    private static final int CORE_POOL_SIZE = 20;

    /**
     * 最大线程数
     */
    private static final int MAX_POOL_SIZE = 100;

    /**
     * 允许线程空闲的时间（秒）
     */
    private static final int KEEP_ALIVE_TIME = 10;

    /**
     * 缓冲队列大小
     */
    private static final int QUEUE_CAPACITY = 200;

    /**
     * 线程池名称前缀
     */
    private static final String THREAD_NAME_PREFIX = "Async-Service-";

    @Bean("taskExecutor")
    public ThreadPoolTaskExecutor taskExecutor() {
        return new ThreadPoolTaskExecutor() {{
            setCorePoolSize(CORE_POOL_SIZE);
            setMaxPoolSize(MAX_POOL_SIZE);
            setQueueCapacity(QUEUE_CAPACITY);
            setKeepAliveSeconds(KEEP_ALIVE_TIME);
            setThreadNamePrefix(THREAD_NAME_PREFIX);

            // 拒绝任务处理策略，CallerRunsPolicy()表示由调用线程池的线程自行执行任务
            setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
            initialize();
        }};
    }
}
```

how to use

``` java
// 伪代码
@Component
class XXX {

    @Async("taskExecutor")
    public void runT_1() { // TODO }

    @Async("taskExecutor")
    public void runT_2() { // TODO }
}

// 伪代码
class XXX2 {

    @Autowired
    private XXX xxx;

    psvm() {
        xxx.runT_1();
        xxx.runT_2();
    }
}
```