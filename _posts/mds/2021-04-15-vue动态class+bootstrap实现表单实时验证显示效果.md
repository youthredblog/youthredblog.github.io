---
layout: post
title: "利用vue的监听和动态class绑定"
# subtitle: ""
date: 2021-04-15 15:22:28
author: youthred
header-img: "img/jk-siwa.png"
catalog: true
tags: [VUE]
---

![GIF](https://wx1.sinaimg.cn/large/005Ii7rngy1gcmkqqcebyg30c302umy9.gif)

这里模拟检测输入的字符串是否为“admin”

## html

``` html
<div id="loginFrom" class="form-group has-feedback" :class="checkStatus.hasClass">
    <div>
        <input name="username" type="text" class="form-control" placeholder="username" v-model="formData.username">
        <span class="glyphicon form-control-feedback" :class="checkStatus.iconClass"></span>
    </div>
</div>
```

## vue

``` js
new Vue({
    el: '#app',
    data: {
        formData: {
            username: ''
        },

        checkStatus: {
            hasClass: '',
            iconClass: ''
        }
    },
    created: function () {},
    methods: {},
    watch: {
        'formData.username': function (newValue, oldValue) {
            if (newValue.trim() === 'admin') {
                this.checkStatus.hasClass = 'has-success';
                this.checkStatus.iconClass = 'glyphicon-ok'
            } else {
                this.checkStatus.hasClass = 'has-error';
                this.checkStatus.iconClass = 'glyphicon-remove'
            }
            console.log(newValue + ' -- ' + oldValue)
        }
    }
})
```

==注意watch监听里不要用箭头函数，箭头函数支持不好==