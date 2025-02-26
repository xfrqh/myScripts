#!/bin/bash

# addr=${ipAddr}
# ssh ubuntu bash -x /etc/script/stun_update.sh  Clash_Proxy time time "192.168.5.1" "587" "192.168.5.1:587"
echo "0 $0 1 $1 2 $2 3 $3 4 $4 5 $5 6 $6" >/var/log/stun.log
ruleName=$1
time=$2
ip=$4
port=$5
addr=$6

function curl_transfer() {
  local method="$1"
  local local_file="$2"
  local relative_path="$3"

  # 预设用户信息
  local user="name"
  local password="pwd"
  local base_url="http://192.168.0.0:114514/dav"

  # 拼接完整的 URL
  local remote_url="$base_url$relative_path"

  case "$method" in
  upload)
    curl -u "$user:$password" -T "$local_file" "$remote_url"
    ;;
  download)
    curl -u "$user:$password" -o "$local_file" "$remote_url" -L
    ;;
  *)
    echo "Invalid method. Please use 'upload' or 'download'."
    exit 1
    ;;
  esac
}
# 示例用法：
# curl_transfer upload myfile.txt /path/to/upload
# curl_transfer download /path/to/download/file.txt downloaded_file

function modify_ini() {
  section="$1"
  key="$2"
  value="$3"
  file="$4"

  sed -i "s/\($section\).*$key *=.*$/\1$key = $value/" "$file"
}

# 发送邮件
function send_email() {
  python3 /etc/script/mail/send_email.py "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}

# 编辑节点信息
function Edit_Proxy_Info() {
  function Edit() {
    proxy_name=$1
    curl_transfer download $temp_file $proxy_path_remote
    sed -i "/$proxy_name/s/port: [0-9]*/port: $port/" $temp_file
    curl_transfer upload $temp_file $proxy_path_remote
  }

  # 检查 ruleName 是否存在于关联数组中
  if [[ -v proxiesMap["$ruleName"] ]]; then
    value="${proxiesMap["$ruleName"]}"
    Edit "$value"
  else
    echo "未找到Clash节点映射，尝试修改$ruleName 对应的端口"
    Edit "$ruleName"
    exit 1
  fi
}

function Summary_sheet() {
  # 汇总表
  curl_transfer download $info_path_local $info_path_remote
  modify_ini "Port" $ruleName ${port} $info_path_local
  curl_transfer upload $info_path_local $info_path_remote.2.ini
  cat $info_path_local
}

base_remote=/path/DDNS

temp_file=/tmp/stun/info.txt
port_path_remote=$base_remote/$ruleName.txt
proxy_path_remote=$base_remote/Clash_proxies.yml

# info_path_remote=$base_remote/info.ini

subject="STUN"
body="$ruleName: $port"
# sender="qq"
# recipient="qq"

declare -A proxiesMap # 声明关联数组
# 初始化键值对
proxiesMap["Clash_Proxy"]="Server 2.2"
proxiesMap["key3"]="value3" # 可以轻松添加更多键值对

mkdir -p /tmp/stun


# 每个规则的专有文件
echo $port >$temp_file
curl_transfer upload $temp_file $port_path_remote

# 修改 Clash 配置
Edit_Proxy_Info

# Summary_sheet

rm -rf /tmp/stun # 删除垃圾

send_email "$subject" "$body"
