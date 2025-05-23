---
layout: post
title: "xargs+rsync并行断点续传自动增量同步"
# subtitle: ""
date: 2025-05-08 18:04:00
author: youthred
header-img: "img/onepunch.png"
catalog: true
tags: [Shell]
---

rsync原生不支持多线程

rsync可以被注册为systemctl服务，但本篇不做讨论，代码越简单越好

直接贴代码

```shell
# 本地
find /local_path -type f -print0 | xargs -0 -I% -P5 rsync -avP % /local_path2

# 远程
find /local_path -type f -print0 | xargs -0 -I% -P5 rsync -avrP % remote_user@remote_ip:/remote_path

# 简单解释
# -type f 递归找寻/local_path下所有文件
# -print0 标准输出处理文件名称的特殊字符（空格、换行符等）
# -0 使用NULL作为分隔符，与-print0搭配使用
# -I% 参数变量名称指定为%
# -P5 最大并行数5
# -avrP -a归档 -v增加输出信息 -r递归子目录并保持目录结构 -P显示进度并支持断点续传
```

执行远程同步后会提示输密码，进一步编写脚本以自动化

rsync.sh

```shell
#!/bin/bash
# author https://github.com/youthred

help() {
  echo '-f | --from 本地文件'
  echo '-t | --to 远端文件'
  echo '-p | --pass 远端密码'
  echo '-L | --logfile 日志文件'
  echo "示例: sh rsync.sh -f/tmp/a.txt -tru@rip:/tmp/ -p'123456' -L/home/test/rsync.log"
}

o="f:t:p:"
longo="from:,to:,pass:,help"
OPTS=$(getopt --options $o --longoptions $longo -- "$@")

if [ $? -ne 0 ]; then
  echo "参数解析失败"
  exit 1
fi

# 将位置参数重置为解析后的选项
eval set -- "OPTS"

from=""
to=""
pass=""
logfile="rsync_push.log"

while true; do
  case "$1" in
    -f | --from)
      from="$2"
      shift 2
      ;;
    -t | --to)
      to="$2"
      shift 2
      ;;
    -p | --pass)
      pass="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    --help)
      help
      exit 0
      ;;
  esac
done

if [[ -z "$from" || -z "$to" ]]; then
  echo "参数不完整"
  exit 1
fi

log() {
  # $(date '+%Y-%m-%d %H:%M:%S')
  # echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> ${logfile}_$(date '+%y%m%d')
  str="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo -e $str >> ${logfile}_$(date '+%y%m%d')
  echo -e $str
}

# rsync执行结果
# expect默认超时30S，会导致大文件未传输完就G了，设置为-1表示无超时
rsyncexecres=$(expect -d -c "
set timeout -1
spawn rsync -avP $from $to
expect {
  \"yes/no\" { send \"yes\r\"; exp_continue }
  \"assword:\" { send \"$pass\r\" }
  eof { exit }
}
expect eof
")

log $rsyncexecres
echo $rsyncexecres

```

使用

```shell
ls $(pwd) | xargs -I% -P5 sh rsync.sh -f$(pwd)/% -tru@rip:/rp/ -p'123456' -Lsynclogfile
find /local_path -type f -print0 | xargs -0 -I% -P5 sh rsync.sh -f% -tru@rip:/rp/ -p'123456' -Lsynclogfile
find $(pwd) -maxdepth 1 ! -path "$(pwd)" -print0 | xargs -0 -I% -P5 sh rsync.sh -f% -tru@rip:/rp/ -p'123456' -Lsynclogfile
```
