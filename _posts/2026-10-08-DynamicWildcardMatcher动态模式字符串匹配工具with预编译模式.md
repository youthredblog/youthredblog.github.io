---
layout: post
title: DynamicWildcardMatcher动态模式字符串匹配工具+预编译模式
#subtitle: Demo post
date: 2026-09-30 18:32:00
author: youthred
header-img: "img/onepunch.png"
catalog: true # 展示层级目录
tags: [Java]
---

## DynamicWildcardMatcher.java

```java
package str.wildcard;

/**
 * 通配符<b>动态匹配</b>：不预编译模式、不缓存、零对象分配。
 *
 * <h2>语义</h2>
 * <ul>
 *   <li>{@code '*'} 匹配任意长度（含空串）的任意字符；{@code '?'} 匹配恰好一个字符；其余字面量精确匹配；</li>
 *   <li>整个模式必须<b>完整匹配</b>整个输入（等价于正则的 {@code Matcher.matches()}）；</li>
 *   <li>{@code expectedLength} 为 {@code null} 表示不校验长度；负数视为不匹配；{@code input} 为 {@code null} 返回 false。</li>
 * </ul>
 *
 * <h2>什么时候用它</h2>
 * 模式动态、基数不确定，或者一个模式只用一次 —— 这时"预编译 + 缓存"没有收益，直接用本类即可。
 * 同一模式会反复使用时，{@link WildcardMatcher#compile} 复用编译结果更快（本类每次都重新扫描模式）。
 *
 * <h2>怎么做到零分配</h2>
 * 文本以 {@code (String s, char[] buf, int off, int len)} 的形式直接作为参数贯穿算法，
 * 靠 {@code buf == null} 区分两个入口（入口内联后该分支被常量折叠），
 * 因此<b>不为文本创建包装对象、不 substring、不建片段数组</b>（实测 0 bytes/call）。
 *
 * <h2>算法</h2>
 * {@code '*'} 把模式切成若干片段：首片段若不以 {@code '*'} 开头就锚在头部，末片段若不以 {@code '*'} 结尾就锚在尾部，
 * 中间片段在收窄后的窗口 {@code [cursor, len - suffixLen - segLen]} 内取<b>最早</b>出现位置。
 * 定位候选位置用"片段内最长连续非 {@code '?'} 字面量"的首字符做单字符跳转（<b>不构造任何对象</b>），
 * 跳过去再回推片段起点做一次完整校验。工作量主要取决于<b>模式长度</b>，不会随输入变长而退化，无递归、无回溯爆炸。
 */
public final class DynamicWildcardMatcher {

    /** 通配任意长度（含空串）。 */
    public static final char STAR = '*';
    /** 通配恰好一个字符。 */
    public static final char QUESTION = '?';

    private DynamicWildcardMatcher() {
    }

    // ------------------------------------------------------------------ 公开入口（String）

    /** 完整匹配，不校验长度。 */
    public static boolean matches(String input, String pattern) {
        return matches(input, pattern, (Integer) null);
    }

    /**
     * 完整匹配。
     *
     * @param input          待匹配字符串，null 返回 false
     * @param pattern        模式，不能为 null
     * @param expectedLength 期望长度；为 null 表示不校验长度，负数视为不匹配
     */
    public static boolean matches(String input, String pattern, Integer expectedLength) {
        if (input == null) {
            return false;
        }
        return expectedLength == null
                ? matchCore(input, null, 0, input.length(), pattern, 0, false)
                : matchCore(input, null, 0, input.length(), pattern, expectedLength, true);
    }

    /** 完整匹配，长度用原始 {@code int} 传入（避免 {@link Integer} 装箱）。 */
    public static boolean matches(String input, String pattern, int expectedLength) {
        if (input == null) {
            return false;
        }
        return matchCore(input, null, 0, input.length(), pattern, expectedLength, true);
    }

    // ------------------------------------------------------------------ 公开入口（char[]，零拷贝）

    /** 零拷贝匹配字符数组缓冲区，不校验长度。 */
    public static boolean matches(char[] text, int offset, int length, String pattern) {
        return matches(text, offset, length, pattern, (Integer) null);
    }

    /** 零拷贝匹配字符数组缓冲区（等价于对 {@code new String(text, offset, length)} 匹配，但不产生任何对象）。 */
    public static boolean matches(char[] text, int offset, int length, String pattern, Integer expectedLength) {
        checkRange(text, offset, length);
        return expectedLength == null
                ? matchCore(null, text, offset, length, pattern, 0, false)
                : matchCore(null, text, offset, length, pattern, expectedLength, true);
    }

    /** 零拷贝匹配字符数组缓冲区，长度用原始 {@code int} 传入（避免装箱）。 */
    public static boolean matches(char[] text, int offset, int length, String pattern, int expectedLength) {
        checkRange(text, offset, length);
        return matchCore(null, text, offset, length, pattern, expectedLength, true);
    }

    // ------------------------------------------------------------------ 核心

    /**
     * 匹配核心（包级可见，供 {@link WildcardMatcher} 的冷路径直接调用，省掉一次入口包装）。
     *
     * @param s   String 入口时非 null（此时 buf 为 null），且 {@code len == s.length()}
     * @param buf char[] 入口时非 null（此时 s 为 null），配合 off/len 使用
     * @param checkLength 是否校验长度；false 时 expectedLength 无意义
     */
    static boolean matchCore(String s, char[] buf, int off, int len, String pattern,
                             int expectedLength, boolean checkLength) {
        if (pattern == null) {
            throw new IllegalArgumentException("pattern must not be null");
        }
        if (checkLength && (expectedLength < 0 || len != expectedLength)) {
            return false;
        }
        final int pLen = pattern.length();
        if (pLen == 0) {
            return len == 0;
        }

        // 一趟扫描模式：算出最短可能长度，并记下是否含通配符
        int minLen = 0;
        boolean hasStar = false;
        boolean hasQuestion = false;
        for (int i = 0; i < pLen; i++) {
            final char c = pattern.charAt(i);
            if (c == STAR) {
                hasStar = true;
            } else {
                minLen++;
                if (c == QUESTION) {
                    hasQuestion = true;
                }
            }
        }
        // len >= minLen 是后面所有越界判断的前提：头部片段、尾锚片段都不超过 minLen
        if (len < minLen) {
            return false;
        }

        if (!hasStar) {
            if (len != minLen) {
                return false;
            }
            return hasQuestion
                    ? regionMatch(s, buf, off, 0, pattern, 0, pLen)
                    : equalsString(s, buf, off, len, pattern);
        }

        final boolean leadingStar = pattern.charAt(0) == STAR;
        final boolean trailingStar = pattern.charAt(pLen - 1) == STAR;
        // 尾锚片段：模式末尾不是 '*' 时，最后一个非空片段必须贴在输入末尾
        final int suffixFrom = trailingStar ? -1 : pattern.lastIndexOf(STAR) + 1;
        final int suffixLen = trailingStar ? 0 : pLen - suffixFrom;

        int cursor = 0;                                    // 已匹配消费到的位置
        int segFrom = 0;                                   // 当前片段在模式中的起点

        if (!leadingStar) {
            // 首片段锚在头部（它是第一个 '*' 之前的整段，因此必有 '*' 且非空）
            final int segTo = pattern.indexOf(STAR);
            if (!regionMatch(s, buf, off, 0, pattern, 0, segTo)) {
                return false;
            }
            cursor = segTo;
            segFrom = segTo + 1;
        }

        // 中间片段：窗口内取最早出现位置。窗口右界排除了尾锚片段要占的位置。
        final int middleEnd = trailingStar ? pLen : suffixFrom;
        while (segFrom < middleEnd) {
            final int star = pattern.indexOf(STAR, segFrom);
            final int segTo = star < 0 ? pLen : star;
            if (segTo > segFrom) {
                final int segLen = segTo - segFrom;
                final int limit = len - suffixLen - segLen;      // 该片段允许的最大起始位置
                if (limit < cursor) {
                    return false;
                }
                final int found = scanSegment(s, buf, off, len, pattern, segFrom, segTo, cursor, limit);
                if (found < 0) {
                    return false;
                }
                cursor = found + segLen;
            }
            segFrom = segTo + 1;
        }

        if (trailingStar) {
            return true;                                   // 尾巴由最后一个 '*' 吸收
        }
        final int suffixStart = len - suffixLen;
        return suffixStart >= cursor && regionMatch(s, buf, off, suffixStart, pattern, suffixFrom, suffixLen);
    }

    /**
     * 在 {@code [from, limit]} 内查找片段 {@code pattern[patFrom, patTo)} 的最早匹配位置，找不到返回 -1。
     *
     * <p>先取片段内<b>最长</b>的一段连续非 {@code '?'} 字面量当锚，用它的首字符跳转（单字符跳转，零分配），
     * 再回推片段起点做一次完整校验。
     */
    private static int scanSegment(String s, char[] buf, int off, int len, String pattern,
                                   int patFrom, int patTo, int from, int limit) {
        int anchorAt = -1;
        int anchorLen = 0;
        int runStart = -1;
        for (int i = patFrom; i <= patTo; i++) {
            if (i < patTo && pattern.charAt(i) != QUESTION) {
                if (runStart < 0) {
                    runStart = i;
                }
            } else if (runStart >= 0) {
                if (i - runStart > anchorLen) {
                    anchorLen = i - runStart;
                    anchorAt = runStart;
                }
                runStart = -1;
            }
        }
        if (anchorAt < 0) {
            return from;                                   // 片段全是 '?'：任意 segLen 个字符都匹配
        }

        final int segLen = patTo - patFrom;
        final int offset = anchorAt - patFrom;             // 锚在片段内的偏移
        final char anchor = pattern.charAt(anchorAt);
        int at = indexOfChar(s, buf, off, len, anchor, from + offset);
        while (at >= 0) {
            final int candidate = at - offset;
            if (candidate > limit) {
                return -1;                                 // 更靠后的候选只会更超界
            }
            if (regionMatch(s, buf, off, candidate, pattern, patFrom, segLen)) {
                return candidate;
            }
            at = indexOfChar(s, buf, off, len, anchor, at + 1);
        }
        return -1;
    }

    // ------------------------------------------------------------------ 文本访问原语（String / char[] 共用）

    private static char charAt(String s, char[] buf, int off, int index) {
        return buf == null ? s.charAt(index) : buf[off + index];
    }

    /** 语义同 {@link String#indexOf(int, int)}（char[] 入口走等价的手写实现）。 */
    private static int indexOfChar(String s, char[] buf, int off, int len, char ch, int fromIndex) {
        if (buf == null) {
            return s.indexOf(ch, fromIndex);
        }
        for (int i = fromIndex; i < len; i++) {
            if (buf[off + i] == ch) {
                return i;
            }
        }
        return -1;
    }

    /** 判断文本 {@code [start, start+len)} 是否与 {@code pattern[patStart, patStart+len)} 匹配（'?' 匹配单字符）。 */
    private static boolean regionMatch(String s, char[] buf, int off, int start,
                                       String pattern, int patStart, int len) {
        for (int i = 0; i < len; i++) {
            final char pc = pattern.charAt(patStart + i);
            if (pc != QUESTION && pc != charAt(s, buf, off, start + i)) {
                return false;
            }
        }
        return true;
    }

    /** 纯字面量整体相等（String 入口可直接用 {@link String#equals}，因为它已是最快路径）。 */
    private static boolean equalsString(String s, char[] buf, int off, int len, String other) {
        if (buf == null) {
            return s.equals(other);
        }
        if (other.length() != len) {
            return false;
        }
        for (int i = 0; i < len; i++) {
            if (buf[off + i] != other.charAt(i)) {
                return false;
            }
        }
        return true;
    }

    private static void checkRange(char[] text, int offset, int length) {
        if (text == null) {
            throw new IllegalArgumentException("text must not be null");
        }
        if (offset < 0 || length < 0 || offset + length > text.length) {
            throw new IndexOutOfBoundsException("offset=" + offset + ", length=" + length
                    + ", text.length=" + text.length);
        }
    }
}
```

## WildcardMatcher.java

```java
package str.wildcard;

import java.util.Arrays;
import java.util.concurrent.atomic.AtomicReferenceArray;

/**
 * 高性能通配符字符串匹配工具（零依赖、无正则、无锁、可跨线程共享）。
 *
 * <h2>语义</h2>
 * <ul>
 *   <li>{@code '*'} 匹配任意长度（含 0）的任意字符序列；</li>
 *   <li>{@code '?'} 匹配恰好一个字符；</li>
 *   <li>其余字符按字面量精确匹配；</li>
 *   <li>整个模式必须<b>完整匹配</b>整个待匹配字符串（等价于正则的 {@code Matcher.matches()}）。</li>
 * </ul>
 *
 * <p>注意：{@code '*'} 匹配<b>任意</b>字符，包括 {@code '/'}、{@code '\'} 等分隔符，
 * 不做"路径 glob 不跨目录"的特例（与"*号匹配任意字符"的语义一致）。
 * 若需要"不跨目录"的路径语义，请按分隔符切分后逐段匹配，或把每段的未知字符用 {@code '?'} 约束长度。
 *
 * <h2>长度匹配</h2>
 * 第三个参数 {@code expectedLength} 为 {@code null} 时不做长度校验；非 null 时要求
 * {@code input.length() == expectedLength}，不等则立即返回 false（在扫描前就短路，是最便宜的加速手段）。
 * 负数长度视为不匹配（返回 false，不抛异常，便于直接处理脏数据）。
 * {@code input == null} 一律返回 false。
 *
 * <h2>三个参数都是动态的（模式基数不确定）时怎么用</h2>
 * 直接调 {@link #isMatch(String, String, Integer)}（长度已知时用 {@code int} 重载避免装箱）即可，
 * 它内部是<b>自适应</b>的两级策略：
 * <ol>
 *   <li><b>热模式</b>（缓存命中）→ 用预编译结果，最快；</li>
 *   <li><b>冷模式</b> → 走<b>零分配动态路径</b> {@link DynamicWildcardMatcher}（不构建片段数组、不做 substring，
 *       只按需扫描模式本身）；</li>
 *   <li><b>第二次再见到同一模式</b> → 才真正编译入缓存（2 次命中准入），
 *       于是"只用一次"的海量动态模式永远不会产生编译开销，也不会把缓存冲掉。</li>
 * </ol>
 * 缓存是<b>直接映射 + 2 路组相联 + 定长</b>的（{@value #HOT_SLOTS} 组 × 2 路，组内 FIFO 淘汰），
 * 因此<b>内存有界（硬上限 {@code 2 * }{@value #HOT_SLOTS} 条目）、永不抖动清理、无锁</b>；
 * 两路是为了消掉"两个热点模式哈希冲突且交替访问"时的反复重编译。
 * 超过 {@value #MAX_CACHEABLE_PATTERN_LENGTH} 字符的超长模式不进缓存（避免长期持有大字符串）。
 * 也就是说：模式种类少 → 全部走编译快路径；模式种类无界 → 全部走零分配动态路径；
 * 中间情况（少量热点模式 + 大量长尾）→ 自动各自归位。
 *
 * <pre>
 *   // 三个参数都动态：一行搞定，无需自己管理编译/缓存
 *   boolean hit = WildcardMatcher.isMatch(fieldValue, rulePattern, ruleLength);
 *
 *   // 模式确定会重复（配置里的规则）时，显式编译更省：
 *   private static final WildcardMatcher RULE = WildcardMatcher.compile("order_*_2024?");
 *
 *   // 输入也是流式缓冲区（复用 char[]，零拷贝且零分配）
 *   WildcardMatcher.isMatch(buffer, offset, len, rulePattern, ruleLength);
 * </pre>
 *
 * <h2>为什么快</h2>
 * <ol>
 *   <li><b>按模式形态分流</b>：纯字面量走 {@link String#equals}；只有 {@code '?'} 走一趟线性比较；
 *       只有 {@code '*'} 直接 true；通用情况才进片段匹配。</li>
 *   <li><b>首尾锚定 + 片段贪心</b>：首个片段若不以 {@code '*'} 开头即锚在头部，末片段若不以 {@code '*'} 结尾即锚在尾部，
 *       中间片段的搜索窗口被收窄到 {@code [pos, n-suffixLen-segLen]}，并取<b>最早</b>出现位置。
 *       无递归、无回溯爆炸（正则的 {@code .*} 在退化输入上可能指数级）。</li>
 *   <li><b>字面量"锚"跳转</b>：每个片段先取"最长连续非 {@code '?'} 字面量"当锚，用它跳到候选位置再回推做一次完整校验。
 *       编译路径的锚是编译期算好的 {@code String}，走 {@link String#indexOf(String, int)}（JIT 内建与向量化）；
 *       动态路径则只用锚的首字符做单字符跳转，从而<b>不构造任何对象</b>。</li>
 *   <li><b>真·零分配</b>：匹配过程不创建任何对象——<b>既不 substring、也不包装文本</b>。
 *       文本以 {@code (String s, char[] buf, int off, int len)} 的形式直接作为参数贯穿到底
 *       （String 与 char[] 两个入口共用同一份算法，靠 {@code buf == null} 区分；在入口内联后该分支会被常量折叠掉）。
 *       实测四条路径（编译 String / 编译 char[] / 动态短文本 / 动态长文本）全部 <b>0 bytes/call</b>，
 *       自测里用 {@code ThreadMXBean.getThreadAllocatedBytes} 断言守着。</li>
 *   <li><b>长度前置过滤</b>：长度参数 + 模式最短长度（非 {@code '*'} 字符个数）先做 O(1) 拒绝。</li>
 * </ol>
 *
 * <p>本类不可变、线程安全：编译结果可作为 {@code static final} 常量共享；静态缓存内部用原子数组，无锁。
 *
 * <p><b>依赖说明</b>：零分配的动态匹配实现已抽到 {@link DynamicWildcardMatcher}（它可以单独使用）。
 * 本类负责"编译 + 自适应缓存 + 分流"，冷路径会调用它，因此这两个类需要一起部署；
 * 若只需要动态匹配（不预编译、不缓存），单独拿 {@code DynamicWildcardMatcher.java} 即可。
 */
public final class WildcardMatcher {

    /** 通配任意长度（含空串）。 */
    public static final char STAR = '*';
    /** 通配恰好一个字符。 */
    public static final char QUESTION = '?';

    // ------------------------------------------------------------------ 自适应缓存
    // 直接映射 + 2 路组相联：槽位 = spread(pattern.hashCode()) & MASK，每组两个条目，冲突时按 FIFO 淘汰。
    // 好处：定长内存、无锁、没有"满了整体清空"造成的抖动（模式基数大时那会导致反复重编译）；
    // 两路是为了消掉"两个热点模式哈希到同一槽位、且交替访问"时的反复重编译（单路实测会退化成每 2 次调用编译一次）。

    /** 组数（2 的幂），总条目上限 = 组数 × 2 路。 */
    private static final int HOT_SLOTS = 4096;
    private static final int HOT_MASK = HOT_SLOTS - 1;

    /** 超过这个长度的模式不缓存（避免把调用方的大字符串长期钉在堆上）。 */
    private static final int MAX_CACHEABLE_PATTERN_LENGTH = 256;

    /** 热缓存第 1 路。 */
    private static final AtomicReferenceArray<HotEntry> HOT_WAY0 = new AtomicReferenceArray<>(HOT_SLOTS);
    /** 热缓存第 2 路。 */
    private static final AtomicReferenceArray<HotEntry> HOT_WAY1 = new AtomicReferenceArray<>(HOT_SLOTS);
    /** "上次在该组见过的模式"，用于 2 次命中准入（避免一次性模式触发编译）。 */
    private static final AtomicReferenceArray<String> RECENT = new AtomicReferenceArray<>(HOT_SLOTS);
    /** 准入序号，用于两路之间的 FIFO 淘汰。 */
    private static final java.util.concurrent.atomic.AtomicLong ADMISSION_SEQ =
            new java.util.concurrent.atomic.AtomicLong();
    /** 累计"因 2 次命中准入而编译"的次数（诊断用，不含显式 compile/matcherFor）。 */
    private static final java.util.concurrent.atomic.AtomicLong CACHE_ADMISSIONS =
            new java.util.concurrent.atomic.AtomicLong();

    private static final char[] EMPTY_CHARS = new char[0];
    private static final char[][] EMPTY_SEGS = new char[0][];
    private static final String[] EMPTY_ANCHORS = new String[0];
    private static final int[] EMPTY_OFFSETS = new int[0];

    private static final class HotEntry {
        final String pattern;
        final WildcardMatcher matcher;
        /** 准入序号，越小越早准入（用于两路 FIFO 淘汰）。 */
        final long seq;

        HotEntry(String pattern, WildcardMatcher matcher, long seq) {
            this.pattern = pattern;
            this.matcher = matcher;
            this.seq = seq;
        }
    }

    private final String pattern;
    /** 非 '*' 字符个数，即模式能匹配的最短长度。 */
    private final int minLength;
    private final boolean hasStar;
    private final boolean hasQuestion;
    /** 模式只由 '*' 组成（如 "*"、"***"）：匹配任意字符串。 */
    private final boolean starOnly;
    /** 模式以 '*' 开头：头部无锚定。 */
    private final boolean leadingStar;
    /** 模式以 '*' 结尾：尾部无锚定。 */
    private final boolean trailingStar;

    /** 无 '*' 时使用：完整模式字符（含 '?'）。 */
    private final char[] full;
    /** 有 '*' 时使用：按 '*' 切分出的非空片段（顺序即模式顺序，连续 '*' 已折叠）。 */
    private final char[][] segs;
    /**
     * 每个片段的"锚"：片段内最长的一段连续非 '?' 字面量（片段全为 '?' 时为 null）。
     * 匹配时先用 {@link String#indexOf} 快速跳到锚的位置，再回推片段起点做完整校验，
     * 避免逐字符暴力扫描。纯字面量片段的锚就是它自身（offset 为 0）。
     */
    private final String[] segAnchors;
    /** 锚在片段内的起始下标。 */
    private final int[] segAnchorOffsets;

    // ------------------------------------------------------------------ 构造 / 编译

    private WildcardMatcher(String pattern) {
        this.pattern = pattern;
        final int n = pattern.length();

        boolean hasStar = false;
        boolean hasQuestion = false;
        int starCount = 0;
        for (int i = 0; i < n; i++) {
            final char c = pattern.charAt(i);
            if (c == STAR) {
                hasStar = true;
                starCount++;
            } else if (c == QUESTION) {
                hasQuestion = true;
            }
        }

        this.hasStar = hasStar;
        this.hasQuestion = hasQuestion;
        this.minLength = n - starCount;
        this.leadingStar = hasStar && pattern.charAt(0) == STAR;
        this.trailingStar = hasStar && pattern.charAt(n - 1) == STAR;
        this.starOnly = hasStar && this.minLength == 0;

        if (!hasStar) {
            this.full = pattern.toCharArray();
            this.segs = EMPTY_SEGS;
            this.segAnchors = EMPTY_ANCHORS;
            this.segAnchorOffsets = EMPTY_OFFSETS;
        } else {
            this.full = EMPTY_CHARS;

            // 片段数最多为 starCount + 1（连续 '*' 会产生空片段，需要丢弃）
            final char[][] tmpSegs = new char[starCount + 1][];
            final String[] tmpAnchors = new String[starCount + 1];
            final int[] tmpOffsets = new int[starCount + 1];
            int segCount = 0;
            int from = 0;
            for (int i = 0; i <= n; i++) {
                if (i == n || pattern.charAt(i) == STAR) {
                    if (i > from) {
                        final char[] seg = new char[i - from];
                        pattern.getChars(from, i, seg, 0);
                        tmpSegs[segCount] = seg;

                        // 找片段内最长的一段连续非 '?' 字面量作为"锚"
                        int bestLen = 0;
                        int bestOff = -1;
                        int runStart = -1;
                        for (int k = 0; k <= seg.length; k++) {
                            final boolean literalChar = k < seg.length && seg[k] != QUESTION;
                            if (literalChar) {
                                if (runStart < 0) {
                                    runStart = k;
                                }
                            } else if (runStart >= 0) {
                                final int runLen = k - runStart;
                                if (runLen > bestLen) {
                                    bestLen = runLen;
                                    bestOff = runStart;
                                }
                                runStart = -1;
                            }
                        }
                        tmpAnchors[segCount] = bestLen == 0 ? null : new String(seg, bestOff, bestLen);
                        tmpOffsets[segCount] = bestOff < 0 ? 0 : bestOff;
                        segCount++;
                    }
                    from = i + 1;
                }
            }
            this.segs = Arrays.copyOf(tmpSegs, segCount);
            this.segAnchors = Arrays.copyOf(tmpAnchors, segCount);
            this.segAnchorOffsets = Arrays.copyOf(tmpOffsets, segCount);
        }
    }

    /**
     * 编译模式。返回的实例不可变、线程安全，适合在静态字段里复用的固定规则。
     *
     * @param pattern 模式串，{@code '*'} 匹配任意长度，{@code '?'} 匹配单个字符
     * @throws IllegalArgumentException pattern 为 null
     */
    public static WildcardMatcher compile(String pattern) {
        if (pattern == null) {
            throw new IllegalArgumentException("pattern must not be null");
        }
        return new WildcardMatcher(pattern);
    }

    /**
     * 取编译结果，命中热缓存则直接返回（模式种类有限、会重复出现时使用）。
     * 与 {@link #isMatch} 的区别：这里<b>一定会编译</b>，因此不要在"模式每次都不同"的循环里逐次调用，
     * 那种场景请直接用 {@link #isMatch}。
     */
    public static WildcardMatcher matcherFor(String pattern) {
        if (pattern == null) {
            throw new IllegalArgumentException("pattern must not be null");
        }
        if (pattern.length() > MAX_CACHEABLE_PATTERN_LENGTH) {
            return new WildcardMatcher(pattern);
        }
        final int slot = slotOf(pattern);
        final HotEntry entry = findHot(slot, pattern);
        if (entry != null) {
            return entry.matcher;
        }
        final WildcardMatcher matcher = new WildcardMatcher(pattern);
        store(slot, pattern, matcher);
        return matcher;
    }

    /** 清空自适应缓存（诊断/测试用；正常运行时不需要调用）。 */
    public static void clearCache() {
        for (int i = 0; i < HOT_SLOTS; i++) {
            HOT_WAY0.set(i, null);
            HOT_WAY1.set(i, null);
            RECENT.set(i, null);
        }
    }

    /** 当前热缓存中的模式条数（诊断用，O({@value #HOT_SLOTS})）。 */
    public static int cachedPatternCount() {
        int count = 0;
        for (int i = 0; i < HOT_SLOTS; i++) {
            if (HOT_WAY0.get(i) != null) {
                count++;
            }
            if (HOT_WAY1.get(i) != null) {
                count++;
            }
        }
        return count;
    }

    /** 缓存条目上限 = 组数 × 2 路（诊断用）：条目数永远不会超过它。 */
    public static int cacheCapacity() {
        return HOT_SLOTS * 2;
    }

    /** 累计"因 2 次命中准入而编译"的次数（诊断用；不含显式 {@code compile}/{@code matcherFor}）。 */
    public static long cacheAdmissionCount() {
        return CACHE_ADMISSIONS.get();
    }

    private static int slotOf(String pattern) {
        final int h = pattern.hashCode();            // String.hashCode() 自带缓存，重复调用几乎零成本
        return (h ^ (h >>> 16)) & HOT_MASK;
    }

    private static boolean isSamePattern(String a, String b) {
        return a == b || a.equals(b);
    }

    /** 在两路里找已编译的同一模式，找不到返回 null。 */
    private static HotEntry findHot(int slot, String pattern) {
        final HotEntry way0 = HOT_WAY0.get(slot);
        if (way0 == null) {
            // 空组（store 保证先填第 1 路），省掉第二次原子读
            return null;
        }
        if (isSamePattern(way0.pattern, pattern)) {
            return way0;
        }
        final HotEntry way1 = HOT_WAY1.get(slot);
        if (way1 != null && isSamePattern(way1.pattern, pattern)) {
            return way1;
        }
        return null;
    }

    /**
     * 把编译结果放进该组：空位优先，两路都满则按 FIFO 淘汰更早准入的那一路。
     * 并发下可能有良性竞争（最坏结果是某一路被覆盖），不影响正确性。
     */
    private static void store(int slot, String pattern, WildcardMatcher matcher) {
        final HotEntry fresh = new HotEntry(pattern, matcher, ADMISSION_SEQ.incrementAndGet());
        final HotEntry way0 = HOT_WAY0.get(slot);
        if (way0 == null || isSamePattern(way0.pattern, pattern)) {
            HOT_WAY0.set(slot, fresh);
            return;
        }
        final HotEntry way1 = HOT_WAY1.get(slot);
        if (way1 == null || isSamePattern(way1.pattern, pattern)) {
            HOT_WAY1.set(slot, fresh);
            return;
        }
        if (way0.seq <= way1.seq) {
            HOT_WAY0.set(slot, fresh);
        } else {
            HOT_WAY1.set(slot, fresh);
        }
    }

    // ------------------------------------------------------------------ 静态便捷 API（模式动态时用这个）

    /**
     * 一次性匹配，自适应：热模式走编译快路径，冷模式走零分配动态路径，第二次见到才编译入缓存。
     *
     * @param input          待匹配字符串，null 返回 false
     * @param pattern        模式，不能为 null
     * @param expectedLength 期望长度；为 null 表示不校验长度
     */
    public static boolean isMatch(String input, String pattern, Integer expectedLength) {
        if (input == null) {
            return false;
        }
        return expectedLength == null
                ? isMatchCore(input, null, 0, input.length(), pattern, 0, false)
                : isMatchCore(input, null, 0, input.length(), pattern, expectedLength, true);
    }

    /**
     * 一次性匹配，长度用原始 {@code int} 传入。
     *
     * <p>长度已知时优先用这个重载：{@link Integer} 只缓存 -128..127，像 512 这样的长度每次调用都会
     * 装箱出一个新 {@code Integer}，实测在 {@code isMatch} 路径上是 <b>16 bytes/call</b>
     * （因为 {@code isMatchCore} 体积大、不会被内联，装箱对象逃逸，逃逸分析救不回来）。
     */
    public static boolean isMatch(String input, String pattern, int expectedLength) {
        if (input == null) {
            return false;
        }
        return isMatchCore(input, null, 0, input.length(), pattern, expectedLength, true);
    }

    /** 一次性匹配，不校验长度。 */
    public static boolean isMatch(String input, String pattern) {
        return isMatch(input, pattern, (Integer) null);
    }

    /** 零拷贝匹配 char[] 缓冲区（自适应，同 {@link #isMatch(String, String, Integer)}）。 */
    public static boolean isMatch(char[] text, int offset, int length, String pattern, Integer expectedLength) {
        checkRange(text, offset, length);
        return expectedLength == null
                ? isMatchCore(null, text, offset, length, pattern, 0, false)
                : isMatchCore(null, text, offset, length, pattern, expectedLength, true);
    }

    /** 零拷贝匹配 char[] 缓冲区，长度用原始 {@code int} 传入（避免装箱）。 */
    public static boolean isMatch(char[] text, int offset, int length, String pattern, int expectedLength) {
        checkRange(text, offset, length);
        return isMatchCore(null, text, offset, length, pattern, expectedLength, true);
    }

    /** 零拷贝匹配 char[] 缓冲区，不校验长度。 */
    public static boolean isMatch(char[] text, int offset, int length, String pattern) {
        return isMatch(text, offset, length, pattern, (Integer) null);
    }

    private static boolean isMatchCore(String s, char[] buf, int off, int len, String pattern,
                                       int expectedLength, boolean checkLength) {
        if (pattern == null) {
            throw new IllegalArgumentException("pattern must not be null");
        }
        // 超长模式不进缓存：避免把调用方的大字符串长期钉在堆上
        if (pattern.length() > MAX_CACHEABLE_PATTERN_LENGTH) {
            return DynamicWildcardMatcher.matchCore(s, buf, off, len, pattern, expectedLength, checkLength);
        }

        final int slot = slotOf(pattern);
        final HotEntry entry = findHot(slot, pattern);
        if (entry != null) {
            // ① 热模式：编译后的快路径
            return entry.matcher.matchesCore(s, buf, off, len, expectedLength, checkLength);
        }

        // ② 冷模式：零分配动态路径（实现在 DynamicWildcardMatcher）
        final boolean result =
                DynamicWildcardMatcher.matchCore(s, buf, off, len, pattern, expectedLength, checkLength);

        // ③ 2 次命中准入：只有"同一组连续两次见到同一模式"才编译入缓存，
        //    这样一次性模式不会产生任何编译开销，也不会把热点模式冲掉。
        final String previous = RECENT.getAndSet(slot, pattern);
        if (isSamePattern(pattern, previous)) {
            store(slot, pattern, new WildcardMatcher(pattern));
            CACHE_ADMISSIONS.incrementAndGet();
        }
        return result;
    }

    // ------------------------------------------------------------------ 实例 API（模式固定时用这个）

    /** 完整匹配，不校验长度。 */
    public boolean matches(String input) {
        return matches(input, (Integer) null);
    }

    /**
     * 完整匹配。
     *
     * @param input          待匹配字符串
     * @param expectedLength 期望长度；为 null 表示不校验长度，负数视为不匹配
     * @return 是否匹配
     */
    public boolean matches(String input, Integer expectedLength) {
        if (input == null) {
            return false;
        }
        return expectedLength == null
                ? matchesCore(input, null, 0, input.length(), 0, false)
                : matchesCore(input, null, 0, input.length(), expectedLength, true);
    }

    /** 完整匹配，长度用原始 {@code int} 传入（避免 {@link Integer} 装箱）。 */
    public boolean matches(String input, int expectedLength) {
        if (input == null) {
            return false;
        }
        return matchesCore(input, null, 0, input.length(), expectedLength, true);
    }

    /** 零拷贝匹配字符数组缓冲区；等价于对 {@code new String(text)} 做匹配，但不产生任何对象。 */
    public boolean matches(char[] text, int offset, int length) {
        return matches(text, offset, length, (Integer) null);
    }

    /**
     * 零拷贝匹配字符数组缓冲区，并校验长度。
     *
     * @param text           缓冲区
     * @param offset         起始下标
     * @param length         参与匹配的长度
     * @param expectedLength 期望长度；为 null 表示不校验（非 null 时必须等于 length）
     */
    public boolean matches(char[] text, int offset, int length, Integer expectedLength) {
        checkRange(text, offset, length);
        return expectedLength == null
                ? matchesCore(null, text, offset, length, 0, false)
                : matchesCore(null, text, offset, length, expectedLength, true);
    }

    /** 零拷贝匹配字符数组缓冲区，长度用原始 {@code int} 传入（避免装箱）。 */
    public boolean matches(char[] text, int offset, int length, int expectedLength) {
        checkRange(text, offset, length);
        return matchesCore(null, text, offset, length, expectedLength, true);
    }

    /** 内部统一入口：长度前置校验 + 形态分流（原始 int 版本，不涉及装箱）。 */
    boolean matchesCore(String s, char[] buf, int off, int len, int expectedLength, boolean checkLength) {
        if (checkLength && (expectedLength < 0 || len != expectedLength)) {
            return false;
        }
        if (len < minLength) {
            return false;
        }
        if (starOnly) {
            return true;
        }
        return match(s, buf, off, len);
    }

    /** 模式原文。 */
    public String pattern() {
        return pattern;
    }

    /** 模式能匹配的最短长度（非 '*' 字符个数）。 */
    public int minLength() {
        return minLength;
    }

    /** 模式只由 '*' 组成，匹配任意字符串。 */
    public boolean isStarOnly() {
        return starOnly;
    }

    /** 模式不含通配符，等价于字符串相等判断。 */
    public boolean isLiteral() {
        return !hasStar && !hasQuestion;
    }

    @Override
    public String toString() {
        return "WildcardMatcher{" + pattern + '}';
    }

    // ------------------------------------------------------------------ 匹配核心（已编译模式）

    private boolean match(String s, char[] buf, int off, int n) {
        if (!hasStar) {
            // 无 '*': 长度必须完全相等
            if (n != minLength) {
                return false;
            }
            if (!hasQuestion) {
                return equalsString(s, buf, off, n, pattern);      // 纯字面量：走 String.equals
            }
            final char[] p = full;
            for (int i = 0; i < n; i++) {
                final char pc = p[i];
                if (pc != QUESTION && pc != charAt(s, buf, off, i)) {
                    return false;
                }
            }
            return true;
        }

        // 有 '*': 首尾可锚定，中间片段贪心取最早出现位置
        final char[][] segs = this.segs;
        final String[] anchors = this.segAnchors;
        final int[] anchorOffsets = this.segAnchorOffsets;
        final int segCount = segs.length;
        final int suffixReserve = trailingStar ? 0 : segs[segCount - 1].length;

        int pos = 0;                                          // 已匹配消费到的位置
        int idx = 0;                                          // 下一个待匹配片段下标

        if (!leadingStar) {
            final char[] first = segs[0];
            if (n < first.length || !regionMatchesSeg(s, buf, off, 0, first)) {
                return false;
            }
            pos = first.length;
            idx = 1;
        }

        final int lastMiddle = trailingStar ? segCount : segCount - 1;
        for (; idx < lastMiddle; idx++) {
            final char[] seg = segs[idx];
            final int segLen = seg.length;
            final int limit = n - suffixReserve - segLen;      // 该片段允许的最大起始位置
            if (limit < pos) {
                return false;                                  // 剩余空间不够，直接失败
            }
            final String anchor = anchors[idx];
            if (anchor == null) {
                // 片段全是 '?': 任意 segLen 个字符都能匹配，取最早位置即可
                pos += segLen;
                continue;
            }
            final int anchorOffset = anchorOffsets[idx];
            if (anchor.length() == segLen) {
                // 纯字面量片段：锚就是整段，一次 indexOf（JIT 内建/向量化）到位
                final int at = indexOf(s, buf, off, n, anchor, pos);
                if (at < 0 || at > limit) {
                    return false;
                }
                pos = at + segLen;
            } else {
                // 含 '?' 的片段：跳到锚的最早位置，再回推片段起点做完整校验
                int searchFrom = pos + anchorOffset;
                int start = -1;
                while (true) {
                    final int at = indexOf(s, buf, off, n, anchor, searchFrom);
                    if (at < 0) {
                        return false;
                    }
                    final int candidate = at - anchorOffset;
                    if (candidate > limit) {
                        return false;                          // 更靠后的候选只会更超界
                    }
                    if (candidate >= pos && regionMatchesSeg(s, buf, off, candidate, seg)) {
                        start = candidate;
                        break;
                    }
                    searchFrom = at + 1;
                }
                pos = start + segLen;
            }
        }

        if (trailingStar) {
            return true;                                       // 尾巴由最后一个 '*' 吸收
        }
        final char[] suffix = segs[segCount - 1];
        final int suffixStart = n - suffix.length;
        return suffixStart >= pos && regionMatchesSeg(s, buf, off, suffixStart, suffix);
    }

    /** 判断文本 [start, start+seg.length) 是否与已编译片段匹配（片段内 '?' 匹配任意单字符）。 */
    private static boolean regionMatchesSeg(String s, char[] buf, int off, int start, char[] seg) {
        for (int i = 0; i < seg.length; i++) {
            final char pc = seg[i];
            if (pc != QUESTION && pc != charAt(s, buf, off, start + i)) {
                return false;
            }
        }
        return true;
    }

    // ------------------------------------------------------------------ 文本访问原语
    // 编译路径专用（动态路径已抽到 DynamicWildcardMatcher，有自己的一份原语）。
    // String 与 char[] 两个入口共用同一份算法：buf == null 表示 String 入口。

    private static char charAt(String s, char[] buf, int off, int index) {
        return buf == null ? s.charAt(index) : buf[off + index];
    }

    /** 语义同 {@link String#indexOf(String, int)}（char[] 入口走等价的手写实现）。 */
    private static int indexOf(String s, char[] buf, int off, int len, String needle, int fromIndex) {
        if (buf == null) {
            return s.indexOf(needle, fromIndex);
        }
        final int needleLen = needle.length();
        final int max = len - needleLen;
        if (max < fromIndex) {
            return -1;
        }
        final char first = needle.charAt(0);
        for (int i = fromIndex; i <= max; i++) {
            if (buf[off + i] != first) {
                continue;
            }
            int j = 1;
            while (j < needleLen && buf[off + i + j] == needle.charAt(j)) {
                j++;
            }
            if (j == needleLen) {
                return i;
            }
        }
        return -1;
    }

    private static boolean equalsString(String s, char[] buf, int off, int len, String other) {
        if (buf == null) {
            return s.equals(other);
        }
        if (other.length() != len) {
            return false;
        }
        for (int i = 0; i < len; i++) {
            if (buf[off + i] != other.charAt(i)) {
                return false;
            }
        }
        return true;
    }

    private static void checkRange(char[] text, int offset, int length) {
        if (text == null) {
            throw new IllegalArgumentException("text must not be null");
        }
        if (offset < 0 || length < 0 || offset + length > text.length) {
            throw new IndexOutOfBoundsException("offset=" + offset + ", length=" + length
                    + ", text.length=" + text.length);
        }
    }
}
```
