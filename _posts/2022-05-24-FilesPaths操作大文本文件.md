---
layout: post
title: "FilesPaths操作大文本文件"
#subtitle: ""
date: 2022-05-24 09:31:47
author: youthred
header-img: img/jk-siwa.png
catalog: true
tags: [Java]
---

``` java
import com.alibaba.fastjson.JSON;
import org.apache.commons.lang3.Validate;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

/**
 * @author youthred
 */
public class FileUtil {

    private String parentPath;

    public FileUtil(String parentPath) {
        this.parentPath = parentPath;
    }

    /**
     * 新增文件
     *
     * @param fileName 完整文件名称（包括后缀）
     * @param data 存入数据
     * @return 文件绝对路径
     * @throws IOException e
     */
    public String save(String fileName, String data) throws IOException {
        Path path = Paths.get(parentPath, fileName);
        Validate.isTrue(Files.notExists(path), "文件已存在");
        Files.createFile(path);
        BufferedWriter bufferedWriter = Files.newBufferedWriter(path, StandardCharsets.UTF_8);
        bufferedWriter.write(data); // 写入自动缓存优化
        bufferedWriter.flush();
        bufferedWriter.close();
        return path.toString();
    }

    /**
     * 覆盖原文档
     *
     * @param fileName 完整文件名称（包括后缀）
     * @param data 存入数据
     * @throws IOException e
     */
    public void update(String fileName, String data) throws IOException {
        Path path = Paths.get(parentPath, fileName);
        // 覆盖
        if (!Files.exists(path)) {
            Files.createFile(path);
        }
        BufferedWriter bufferedWriter = Files.newBufferedWriter(path, StandardCharsets.UTF_8);
        bufferedWriter.write(data);
        bufferedWriter.flush();
        bufferedWriter.close();
    }

    /**
     * 删除文档
     *
     * @param fileName 完整文件名称（包括后缀）
     * @return 删除成功与否
     * @throws IOException e
     */
    public boolean delete(String fileName) throws IOException {
        Path path = Paths.get(parentPath, fileName);
        return Files.deleteIfExists(path);
    }

    /**
     * 获取文档
     *
     * @param fileName 完整文件名称（包括后缀）
     * @return 文档数据
     * @throws IOException e
     */
    public String get(String fileName) throws IOException {
        Path path = Paths.get(parentPath, fileName);
        String line;
        StringBuilder data = new StringBuilder();
        BufferedReader bufferedReader = Files.newBufferedReader(path, StandardCharsets.UTF_8);
        while ((line = bufferedReader.readLine()) != null) {
            data.append(line).append("\n");
        }
        return data.toString();
    }

    /**
     * 获取文档
     *
     * @param fileName 完整文件名称（包括后缀）
     * @return 文档数据
     * @throws IOException e
     */
    public <T> List<T> get2parseArray(String fileName, Class<T> clazz) throws IOException {
        return JSON.parseArray(this.get(fileName), clazz);
    }

    /**
     * 获取文档
     *
     * @param fileName 完整文件名称（包括后缀）
     * @return 文档数据
     * @throws IOException e
     */
    public <T> T get2parseObject(String fileName, Class<T> clazz) throws IOException {
        return JSON.parseObject(this.get(fileName), clazz);
    }
}
```