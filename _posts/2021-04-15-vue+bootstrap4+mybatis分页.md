---
layout: post
title: "vue+bootstrap4+mybatis分页"
# subtitle: ""
date: 2021-04-15 22:12:28
author: youthred
header-img: "img/onepunch.png"
catalog: true
tags: [VUE]
---

![gif](https://wx4.sinaimg.cn/large/005Ii7rngy1gb0nmqlruag31gy0qpb29.gif)

Springboot+Mybatis+Pagehelper分页具体实现略。

## Controller返回数据

``` java
@GetMapping("/findByPage")
    public AjaxResult findByPage(@RequestParam("pageIndex") Integer pageIndex, @RequestParam("pageSize") Integer pageSize) {
        PageInfo<Article> articlePageInfo = articleService.findByPage(pageIndex, pageSize, Sort.DESC.getSort());
        return AjaxResult.me().setResultObj(new HashMap<String, Object>(3) {{
            put("total", articlePageInfo.getTotal());
            put("list", articlePageInfo.getList());
            put("pages", articlePageInfo.getPages());
        }});
    }
```



## js vue

articles里有三个字段：

total（数据不分页总条数，暂时无用，因为没有做具体页数的按钮），

list（当前页数据），

pages（分页总页数）

默认首次打开页面的页号为1，每页数据条数为5

``` js
window.onload = function() {
    new Vue({
        el: '#app',
        data: {
            articles: '',
            page: {
                index: 1,
                size: 5
            }
        },
        methods: {
            pageInfo() {
                $.get('/article/findByPage', {'pageIndex': this.page.index, 'pageSize': this.page.size}, (result) => {
                    // ajax获取数据，result.resultObj={total,list,pages}，赋给vue字段articles
                    this.articles = result.resultObj
                })
            },
            // 上一页，边界由html页面控制
            prev() {
                this.page.index --;
                this.pageInfo()
            },
            // 下一页，边界由html页面控制
            next() {
                this.page.index ++;
                this.pageInfo()
            }
        },
        created: function () {
            // 页面创建后默认分页
            this.pageInfo()
        }
    })
}
```



## html，按钮控制，解决边界问题

通过vue的条件控制来保证分页不越界，pageIndex == 1 时禁用prev按钮，pageIndex == articles.pages（总页数）时禁用next按钮

``` html
<div class="btn-group">
    <!--prev-->
    <button v-if="page.index == 1" type="button" class="btn btn-outline-success" disabled><i class="fa fa-chevron-left" aria-hidden="true"></i></button>
    <button v-if="page.index > 1" id="prev" type="button" class="btn btn-outline-success"><i class="fa fa-chevron-left" aria-hidden="true" @click="prev()"></i></button>
    <!--pageIndex/pages-->
    <button type="button" class="btn btn-outline-success">{{page.index}}/{{articles.pages}}</button>
    <!--next-->
    <button v-if="page.index == articles.pages" type="button" class="btn btn-outline-success" disabled><i class="fa fa-chevron-right" aria-hidden="true"></i></button>
    <button v-if="page.index < articles.pages" id="next" type="button" class="btn btn-outline-success"><i class="fa fa-chevron-right" aria-hidden="true" @click="next()"></i></button>
</div>
```