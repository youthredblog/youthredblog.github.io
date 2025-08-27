---
layout: post
title: "ApacheMime4j解析.eml"
# subtitle: ""
date: 2024-12-10 18:10:00
author: youthred
header-img: "img/onepunch.png"
catalog: true
tags: [Java,Apache]
---

所需依赖

```xml
<dependency>
    <groupId>cn.hutool</groupId>
    <artifactId>hutool-all</artifactId>
    <version>${hutool.version}</version>
</dependency>
<dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-lang3</artifactId>
    <version>${commons-lang3.version}</version>
</dependency>
<dependency>
    <groupId>org.apache.commons</groupId>
    <artifactId>commons-collections4</artifactId>
    <version>4.4</version>
</dependency>
<dependency>
    <groupId>commons-io</groupId>
    <artifactId>commons-io</artifactId>
    <version>${commons-io.version}</version>
</dependency>
<dependency>
    <groupId>org.apache.james</groupId>
    <artifactId>apache-mime4j-dom</artifactId>
    <version>0.8.11</version>
</dependency>
<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>1.18.32</version>
</dependency>
```

Eml实体

```java
package fileparser.eml;

import lombok.Data;
import lombok.experimental.Accessors;
import org.apache.commons.lang3.tuple.Pair;
import org.apache.commons.lang3.tuple.Triple;
import org.apache.james.mime4j.stream.Field;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

@Data
@Accessors(chain = true)
public class Eml implements Serializable {
    private static final long serialVersionUID = 8104266141830934519L;

    private String messageId;
    private String subject;
    private String textContent;
    private String htmlContent;
    /**
     * L:邮箱地址 R:昵称
     */
    private Pair<String, String> from;
    private List<Pair<String, String>> to;
    /**
     * 抄送人
     */
    private List<Pair<String, String>> cc;
    /**
     * 密送人
     */
    private List<Pair<String, String>> bcc;
    private String datetime;
    private List<Field> headers;
    private String headersStr;
    /**
     * L:附件名称 M:字节大小 R:字节数组数据
     */
    private List<Triple<String, Long, byte[]>> attachments = new ArrayList<>();
}
```

.eml解析工具

```java
package fileparser.eml;

import cn.hutool.core.date.DatePattern;
import cn.hutool.core.date.DateUtil;
import cn.hutool.core.io.file.FileNameUtil;
import cn.hutool.core.util.IdUtil;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.collections4.CollectionUtils;
import org.apache.commons.io.IOUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.lang3.exception.ExceptionUtils;
import org.apache.commons.lang3.tuple.ImmutablePair;
import org.apache.commons.lang3.tuple.ImmutableTriple;
import org.apache.commons.lang3.tuple.Pair;
import org.apache.james.mime4j.dom.*;
import org.apache.james.mime4j.dom.address.AddressList;
import org.apache.james.mime4j.dom.address.Group;
import org.apache.james.mime4j.dom.address.Mailbox;
import org.apache.james.mime4j.dom.address.MailboxList;
import org.apache.james.mime4j.dom.field.ContentDispositionField;
import org.apache.james.mime4j.dom.field.ContentTypeField;
import org.apache.james.mime4j.dom.field.FieldName;
import org.apache.james.mime4j.message.MultipartImpl;
import org.apache.james.mime4j.stream.Field;
import org.apache.james.mime4j.stream.MimeConfig;
import org.apache.tomcat.util.http.fileupload.util.mime.MimeUtility;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.*;
import java.util.stream.Collectors;
import java.util.stream.Stream;

@Slf4j
public class EmlParser {

    public static Eml parse(InputStream is) throws IOException {
        return parse(IOUtils.toByteArray(is));
    }

    public static Eml parse(byte[] bytes) throws IOException {
        Message message = Message.Builder.of()
                .use(MimeConfig.PERMISSIVE)
                .parse(new ByteArrayInputStream(bytes))
                .build();
        Eml eml = new Eml()
                .setMessageId(message.getMessageId())
                .setSubject(message.getSubject())
                .setDatetime(DateUtil.format(message.getDate(), DatePattern.NORM_DATETIME_FORMATTER));
        List<Pair<String, String>> froms = parseMailboxList(message.getFrom());
        if (CollectionUtils.isNotEmpty(froms)) {
            eml.setFrom(froms.get(0));
        }
        try {
            eml.setTo(parseAddressList(message.getTo()));
        } catch (Throwable ignored) {
        }
        try {
            eml.setCc(parseAddressList(message.getCc()));
        } catch (Throwable ignored) {
        }
        try {
            eml.setBcc(parseAddressList(message.getBcc()));
        } catch (Throwable ignored) {
        }
        try {
            eml.setHeaders(message.getHeader().getFields())
                    .setHeadersStr(message.getHeader().toString());
        } catch (Throwable ignored) {
        }

        parseBody(Collections.singletonList(message.getBody().getParent()), eml);

        return eml;
    }

    private static void parseBody(List<Entity> bodyParts, Eml eml) throws IOException {
        for (Entity entity : bodyParts) {
            Body bodyContent = entity.getBody();

            // 纯文本
            if (bodyContent instanceof TextBody) {
                TextBody textBody = (TextBody) bodyContent;
                String content = null;
                try (InputStream tbis = textBody.getInputStream()) {
                    content = IOUtils.toString(tbis, entity.getCharset());
                } catch (Throwable ignored) {
                }
                String mimeType = entity.getMimeType();// text/plain text/html
                if (mimeType.contains("plain")) {
                    eml.setTextContent(content);
                }
                if (mimeType.contains("html")) {
                    eml.setHtmlContent(content);
                }
                continue;
            }

            // 二进制(文件/图片等)
            if (bodyContent instanceof BinaryBody) {
                parseBinary(entity, (BinaryBody) bodyContent, eml);
                continue;
            }

            // 更多文件
            if (bodyContent instanceof MultipartImpl) {
                MultipartImpl multipart = (MultipartImpl) bodyContent;
                parseBody(multipart.getBodyParts(), eml);
            }
        }
    }

    private static void parseBinary(Entity entity, BinaryBody binaryBody, Eml eml) {
        Header header = entity.getHeader();

        if (ContentDispositionField.DISPOSITION_TYPE_INLINE.equals(entity.getDispositionType())) {
            if (entity.getMimeType().startsWith("image")) {
                try (InputStream inputStream = binaryBody.getInputStream()) {
                    String base64 = Base64.getEncoder().encodeToString(IOUtils.toByteArray(inputStream));
                    Field contentIdField = header.getField(FieldName.CONTENT_ID);
                    if ((Objects.isNull(contentIdField))) {
                        return;
                    }
                    String cid = StringUtils.substringBetween(contentIdField.getBody(), "<", ">");
                    String data = entity.getMimeType() + ";base64," + base64;
                    String content = StringUtils.replace(eml.getHtmlContent(), "cid:" + cid, "data:" + data);
                    eml.setHtmlContent(content);
                } catch (Throwable e) {
                    log.error(ExceptionUtils.getStackTrace(e));
                }
            }
        } else if (ContentDispositionField.DISPOSITION_TYPE_ATTACHMENT.equals(entity.getDispositionType())) {
            try (InputStream inputStream = binaryBody.getInputStream()) {
                Field contentDispositionField = header.getField(FieldName.CONTENT_DISPOSITION);
                if (Objects.nonNull(contentDispositionField) && contentDispositionField instanceof ContentDispositionField) {
                    String filename = ((ContentDispositionField) contentDispositionField).getFilename();
                    if (StringUtils.isBlank(filename)) {
                        Field contentTypeField = header.getField(FieldName.CONTENT_TYPE);
                        if (Objects.nonNull(contentTypeField) && contentTypeField instanceof ContentTypeField) {
                            filename = ((ContentTypeField) contentTypeField).getParameter("name");
                            if (StringUtils.isBlank(filename)) {
                                filename = IdUtil.nanoId() + "." + ((ContentTypeField) contentTypeField).getSubType();
                            }
                        }
                    }
                    filename = decodeBase64Str(filename);
                    byte[] bytes = IOUtils.toByteArray(inputStream);
                    eml.getAttachments().add(ImmutableTriple.of(filename, (long) bytes.length, bytes));
                }
            } catch (Throwable e) {
                log.error(ExceptionUtils.getStackTrace(e));
            }
        } else {
            // 其他类型
        }
    }

    private static String decodeBase64Str(String str) {
        if (StringUtils.isBlank(str)) {
            return str;
        }
        try {
            str = MimeUtility.decodeText(str);
        } catch (Throwable decodeE) {
            try {
                str = MimeUtility.decodeText(FileNameUtil.cleanInvalid(str));
            } catch (Throwable ignored) {
            }
        }
        return str.trim();
    }

    /**
     * @param mailboxes MailboxList
     * @return L:邮箱地址 R:昵称
     */
    private static List<Pair<String, String>> parseMailboxList(MailboxList mailboxes) {
        if (CollectionUtils.isEmpty(mailboxes)) {
            return Collections.emptyList();
        }
        return mailboxes.stream().map(EmlParser::mailboxToPair).collect(Collectors.toList());
    }

    /**
     * @param mailbox Mailbox
     * @return L:邮箱地址 R:昵称
     */
    private static Pair<String, String> mailboxToPair(Mailbox mailbox) {
        return ImmutablePair.of(mailbox.getAddress(), mailbox.getName());
    }

    /**
     * @param addresses AddressList
     * @return L:邮箱地址 R:昵称
     */
    private static List<Pair<String, String>> parseAddressList(AddressList addresses) {
        if (CollectionUtils.isEmpty(addresses)) {
            return Collections.emptyList();
        }
        return addresses.stream().flatMap(address -> {
            if (address instanceof Mailbox) {
                return Stream.of(mailboxToPair((Mailbox) address));
            }
            if (address instanceof Group) {
                return parseMailboxList(((Group) address).getMailboxes()).stream();
            }
            return null;
        }).filter(Objects::nonNull).collect(Collectors.toList());
    }
}
```
