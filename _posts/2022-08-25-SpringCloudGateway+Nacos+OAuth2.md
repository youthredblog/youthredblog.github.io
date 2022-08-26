---
layout: post
title: "SpringCloudGateway+Nacos+OAuth2"
#subtitle: ""
date: 2022-08-25 13:43:00
author: youthred
header-img: img/jk-siwa.png
catalog: true
tags: [Springboot,SpringCloud,SpringCloudGateway,Nacos,OpenFeign,WebFlux,OAuth2]
---

POM

``` xml
<dependencyManagement>
    <dependencies>
        <!--支持Spring Boot 2.1.X-->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-dependencies</artifactId>
            <version>2.3.2.RELEASE</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-dependencies</artifactId>
            <version>Hoxton.SR8</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-alibaba-dependencies</artifactId>
            <version>2.2.5.RELEASE</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-lang3</artifactId>
            <version>${commons.lang3.version}</version>
        </dependency>
        <dependency>
            <groupId>commons-io</groupId>
            <artifactId>commons-io</artifactId>
            <version>${commons.io.version}</version>
        </dependency>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-collections4</artifactId>
            <version>${commons.collections.version}</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-configuration-processor</artifactId>
            <version>2.3.0.RELEASE</version>
        </dependency>
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>mybatis-plus-boot-starter</artifactId>
            <version>${mybatis.plus.version}</version>
        </dependency>
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>dynamic-datasource-spring-boot-starter</artifactId>
            <version>${dynamic.datasource.version}</version>
        </dependency>
        <dependency>
            <groupId>cn.hutool</groupId>
            <artifactId>hutool-all</artifactId>
            <version>${hutool.version}</version>
        </dependency>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit-platform-launcher</artifactId>
            <version>${junit.platform.launcher.version}</version>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <version>1.18.10</version>
            <scope>compile</scope>
        </dependency>
        <dependency>
            <groupId>com.alibaba</groupId>
            <artifactId>druid-spring-boot-starter</artifactId>
            <version>${druid.starter.version}</version>
        </dependency>
        <dependency>
            <groupId>com.oracle</groupId>
            <artifactId>ojdbc8</artifactId>
            <version>${oracle.version}</version>
            <optional>true</optional>
        </dependency>
        <dependency>
            <groupId>io.gitghub.youthred.common</groupId>
            <artifactId>common</artifactId>
            <version>${io.gitghub.youthred.common.version}</version>
        </dependency>
        <dependency>
            <groupId>p6spy</groupId>
            <artifactId>p6spy</artifactId>
            <version>${p6spy.version}</version>
            <optional>true</optional>
        </dependency>
    </dependencies>
</dependencyManagement>

<properties>
    <spring-boot-maven-plugin.version>2.3.0.RELEASE</spring-boot-maven-plugin.version>
    <maven-surefire-plugin.version>2.22.2</maven-surefire-plugin.version>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
    <maven.compiler.source>1.8</maven.compiler.source>
    <maven.compiler.target>1.8</maven.compiler.target>
    <commons.lang3.version>3.7</commons.lang3.version>
    <commons.io.version>2.6</commons.io.version>
    <commons.collections.version>4.1</commons.collections.version>
    <junit.platform.launcher.version>1.6.2</junit.platform.launcher.version>
    <hutool.version>5.8.3</hutool.version>
    <mybatis.plus.version>3.3.2</mybatis.plus.version>
    <druid.starter.version>1.1.22</druid.starter.version>
    <oracle.version>1.0</oracle.version>
    <io.gitghub.youthred.common.version>0.0.1</io.gitghub.youthred.common.version>
    <p6spy.version>3.8.0</p6spy.version>
    <dynamic.datasource.version>3.1.1</dynamic.datasource.version>
</properties>
```

项目结构

```
goc
+- goc-common 公共模块
+- goc-auth
|  +- goc-authorizer 授权服务（本篇不作说明，只写网关鉴权转发）
|  +- goc-authenticator 鉴权服务
|  +- goc-authenticator-client 鉴权Feign客户端
+- goc-gateway 网关服务
```

## 1 SpringCloudGateway

SpringCloudGateway + Nacos

### 1.1 ReactiveFilter

这里把拦截过滤写在 `WebFilter` 而不是 `GlobalFilter` 是为了拦截所有从网关发起的请求，不仅包含网关转发，还包含Feign远程鉴权等请求。

而如果仅仅实现 `GlobalFilter` 则只能拦截到网关转发的请求。

``` java
/**
 * 拦截所有请求（包括非网关请求）
 *
 * @author youthred.github.io
 */
@Configuration
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.REACTIVE)
// 必须加上组件扫描（Feign客户端）才不会报错"feign.codec.DecodeException: No qualifying bean of type 'org.springframework.boot.autoconfigure.http.HttpMessageConverters' available: expected at least 1 bean which qualifies as autowire candidate. Dependency annotations: {@org.springframework.beans.factory.annotation.Autowired(required=true)}"
@ComponentScan(basePackages = "io.gitghub.youthred.goc.authenticator.client")
@RequiredArgsConstructor
public class ReactiveFilter implements WebFilter, Ordered {

    private final AuthProvider authProvider;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        String roles = request.getHeaders().getFirst(CommonConstant.Header.ROLES);
        ServerHttpRequest.Builder mutate = request.mutate();
        mutate.header(CommonConstant.Header.ROLES, roles);
        // roles 不能未空或空字符串
        // （这里也可以使用feign.RequestInterceptor实现全局header自动填写，但WebFlux的请求上下文暂时没搞明白，用它推荐的Context也无法在非控制层获取到Request，在后面的段落会详细说明）
        // R: 响应封装实体，这里省略说明
        // 为了简单说明，这里直接判断请求路径是否有相关角色
        R<Boolean> permit = authProvider.permit(roles, request.getURI().getPath(), request.getMethodValue());
        if (permit.getCode() == HttpStatus.OK.getCode()) {
            return permit.getData()
                    ? chain
                        // 写入header
                        .filter(exchange.mutate().request(mutate.build()).build())
                        // 写入Context上下文
                        .subscriberContext(ctx -> ctx.put(ReactiveRequestContextHolder.CONTEXT_KEY, request))
                    : ServerWebExchangeUtil.forbidden(exchange);
        }
        return ServerWebExchangeUtil.custom(exchange, permit);
    }

    @Override
    public int getOrder() {
        return 0;
    }
}
```

#### 1.1.1 Reactive请求上下文

``` java
/**
 * Reactive请求上下文
 *
 * @author youthred.github.io
 */
public class ReactiveRequestContextHolder {

    static final Class<ServerHttpRequest> CONTEXT_KEY = ServerHttpRequest.class;

    public static Mono<Context> getContext() {
        return Mono.subscriberContext();
    }

    public static Mono<ServerHttpRequest> getRequest() {
        return Mono.subscriberContext()
                .map(ctx -> ctx.get(CONTEXT_KEY));
    }

    public static Mono<String> getHeader(String headerName) {
        return getRequest().map(request -> request.getHeaders().getFirst(headerName));
    }

    public static Function<Context, Context> clear() {
        return (context) -> context.delete(CONTEXT_KEY);
    }
}
```

#### 1.1.2 Reactive自定义响应工具

``` java
/**
 * @author youthred.github.io
 */
public class ServerWebExchangeUtil {

    /**
     * forbidden
     *
     * @param exchange ServerWebExchange
     * @return Mono<Void>
     */
    public static Mono<Void> forbidden(ServerWebExchange exchange) {
        ServerHttpResponse response = exchange.getResponse();
        DataBuffer buffer = response.bufferFactory().wrap(JSONUtil.toJsonStr(R.forbidden()).getBytes(StandardCharsets.UTF_8));
        response.setStatusCode(HttpStatus.FORBIDDEN);
        response.getHeaders().add(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON);
        return exchange.getResponse().writeWith(Mono.just(buffer));
    }

    /**
     * forbidden
     *
     * @param exchange ServerWebExchange
     * @param r        R
     * @return Mono<Void>
     */
    public static Mono<Void> custom(ServerWebExchange exchange, R r) {
        ServerHttpResponse response = exchange.getResponse();
        DataBuffer buffer = response.bufferFactory().wrap(JSONUtil.toJsonStr(r).getBytes(StandardCharsets.UTF_8));
        response.setStatusCode(HttpStatus.valueOf(r.getCode()));
        response.getHeaders().add(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON);
        return exchange.getResponse().writeWith(Mono.just(buffer));
    }
}
```

### 1.2 Nacos

Nacos gateway.yml

``` yaml
spring:
  cloud:
    gateway:
      routes:
        - id: goc-authenticator
          order: 1
          predicates:
            - Path=/goc-authenticator/**
          filters:
            - StripPrefix=1
          uri: lb://goc-authenticator
```

网关服务 bootstrap.yml

``` yaml
server:
  port: ${GATEWAY_SERVER_PORT}
spring:
  application:
    name: gateway
  cloud:
    nacos:
      discovery:
        server-addr: ${REGISTER_HOST}:${REGISTER_PORT}
      config:
        server-addr: ${REGISTER_HOST}:${REGISTER_PORT}
        enabled: true
        file-extension: yml
        shared-configs:
          - data-id: gateway.yml
            refresh: true
          - data-id: common.yml
            refresh: true
          - data-id: server.yml
            refresh: true
    sentinel:
      transport:
        dashboard: ${SENTINEL_DASHBOARD_HOST}:${SENTINEL_DASHBOARD_PORT}
```

## 2 authenticator 鉴权服务

### 2.1 提供鉴权接口

``` java
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthenticatorRest {

    private final Authenticator authenticator;

    @GetMapping("/permit")
    public R<Boolean> permit(
            @RequestParam("path") String path,
            @RequestParam("method") String method
    ) {
        return R.ok(authenticator.permit(new RequestDto().setPath(path).setMethod(method)));
    }
}
```

### 2.2 鉴权器 `Authenticator`

为了简单说明，这里直接判断请求路径是否有相关角色

``` java
/**
 * 鉴权器
 *
 * @author youthred.github.io
 */
@Service
@RequiredArgsConstructor
public class Authenticator {

    private static final PathMatcher ANT_PATH_MATCHER = new AntPathMatcher();

    private final RedisService redisService;

    /**
     * 鉴权是否通过
     *
     * @param request ServerHttpRequest
     * @return boolean
     */
    public boolean permit(ServerHttpRequest request) {
        String rolesHeaderValue = request.getHeaders().getFirst(CommonConstant.Header.ROLES);
        return doPermit(rolesHeaderValue, request.getMethodValue(), request.getURI().getPath());
    }

    /**
     * 鉴权是否通过
     *
     * @param roles header roles's value
     * @param dto   RequestDto
     * @return boolean
     */
    public boolean permit(String roles, RequestDto dto) {
        return doPermit(roles, dto.getMethod(), dto.getPath());
    }

    /**
     * 鉴权是否通过
     *
     * @param dto RequestDto
     * @return boolean
     */
    public boolean permit(RequestDto dto) {
        // Servlet环境可以直接从默认Context获取请求
        return doPermit(HttpServletUtil.getHeader(CommonConstant.Header.ROLES), dto.getMethod(), dto.getPath());
    }

    private boolean doPermit(String rolesStr, String methodValue, String path) {
        if (StringUtils.isBlank(rolesStr)) {
            return false;
        }
        // cn.hutool.core.convert.Convert
        List<String> hasRoles = Convert.toList(String.class, rolesStr);
        Map<String, List<String>> permissionMapByMethod = redisService.getPermissionRoleTypesMapByMethod(methodValue);
        if (MapUtils.isNotEmpty(permissionMapByMethod)) {
            for (Map.Entry<String, List<String>> e : permissionMapByMethod.entrySet()) {
                if (ANT_PATH_MATCHER.match(e.getKey(), path)) {
                    List<String> needRoles = e.getValue();
                    return CollUtil.containsAny(hasRoles, needRoles);
                }
            }
        }
        // 404
        return false;
    }
}
```

Servlet工具类

``` java
/**
 * @author youthred.github.io
 */
public class HttpServletUtil {

    public static HttpServletRequest getRequestFromContextHolder() {
        RequestAttributes requestAttributes = RequestContextHolder.getRequestAttributes();
        if (Objects.nonNull(requestAttributes)) {
            return ((ServletRequestAttributes) requestAttributes).getRequest();
        }
        return null;
    }

    public static String getHeader(String headerName) {
        HttpServletRequest request = getRequestFromContextHolder();
        return Objects.nonNull(request)
                // cn.hutool.extra.servlet.ServletUtil
                ? ServletUtil.getHeader(getRequestFromContextHolder(), headerName, StandardCharsets.UTF_8)
                : null;
    }
}
```

## 3 authenticator-client 鉴权Feign服务器

### 3.1 POM

``` xml
<properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
    <maven.compiler.source>1.8</maven.compiler.source>
    <maven.compiler.target>1.8</maven.compiler.target>
</properties>

<dependencies>
    <dependency>
        <groupId>io.gitghub.youthred.goc</groupId>
        <artifactId>goc-common</artifactId>
        <version>1.0.0</version>
    </dependency>
    <dependency>
        <groupId>org.springframework.cloud</groupId>
        <artifactId>spring-cloud-starter-openfeign</artifactId>
    </dependency>
</dependencies>

<build>
    <finalName>${project.artifactId}-${project.version}</finalName>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
            <version>${spring-boot-maven-plugin.version}</version>
        </plugin>
    </plugins>
</build>
```

### 3.2

避免报错 `feign.codec.DecodeException: No qualifying bean of type 'org.springframework.boot.autoconfigure.http.HttpMessageConverters' available: expected at least 1 bean which qualifies as autowire candidate. Dependency annotations: {@org.springframework.beans.factory.annotation.Autowired(required=true)}`

```
@Bean
@ConditionalOnMissingBean
public HttpMessageConverters messageConverters(ObjectProvider<HttpMessageConverter<?>> converters) {
    return new HttpMessageConverters(converters.orderedStream().collect(Collectors.toList()));
}
```

### 3.3 AuthProvider

``` java
/**
 * @author youthred.github.io
 */
@FeignClient(name = "goc-authenticator", path = "/auth", fallback = AuthProvider.AuthProviderFallback.class)
public interface AuthProvider {

    @GetMapping("/permit")
    R<Boolean> permit(
            // 这里放入请求头（鉴权服务上不需要这个参数，直接从请求头获取）
            @RequestHeader(CommonConstant.Header.ROLES) String roles,
            @RequestParam("path") String path,
            @RequestParam("method") String method
    );

    @Component
    class AuthProviderFallback implements AuthProvider {

        @Override
        public R<Boolean> permit(String roles, String path, String method) {
            return R.error(false, "Feign Request Timeout");
        }
    }
}
```

### 3.4 开启熔断

``` yaml
feign:
  hystrix:
    enabled: true
```

## 4 完善

### 4.1 Feign Reactive

`1.1` 里说过暂时没有找到合适的方法从上下文中获取Request

``` java
/**
 * 与WebFlux的请求上下文配合自动传递header
 *
 * @author youthred.github.io
 */
@Component
public class FeignInterceptor implements RequestInterceptor {

    @Override
    public void apply(RequestTemplate requestTemplate) {
        ReactiveRequestContextHolder.getHeader(CommonConstant.Header.ROLES)
                .subscribe(rolesStr ->
                    // 这一句不会执行
                    requestTemplate.header(CommonConstant.Header.ROLES, rolesStr)
                );
    }
}
```

不知道为什么不会执行，这个问题暂留。

其实有一个开源项目 [feign-reactive](https://github.com/PlaytikaOSS/feign-reactive) 可以实现，但没有深究如何使用，这里就将就手动使用 `@RequestHeader` 转递，幸好网关的鉴权功能只需要一个接口。

### 4.2 Feign Timeout

开启熔断降级后，一般得自定义远程服务超时时间，默认1S，建议5S

在网关服务端配置

``` yaml
feign:
  client:
    config:
      default: # org.springframework.cloud.openfeign.FeignClientProperties.FeignClientConfiguration
        connect-timeout: 5000
        read-timeout: 5000
```

---

完整代码地址 [youthred/goc](https://github.com/youthred/goc)




