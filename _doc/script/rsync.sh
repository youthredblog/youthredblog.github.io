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
