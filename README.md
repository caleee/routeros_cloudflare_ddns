- [RouterOS Cloudflare DDNS](#routeros-cloudflare-ddns)
  - [介绍](#介绍)
  - [声明](#声明)
  - [必要条件](#必要条件)
  - [使用概述](#使用概述)
  - [脚本内容解析](#脚本内容解析)
    - [变量](#变量)
      - [DEBUG](#debug)
      - [CLOUD](#cloud)
      - [INTERFACE](#interface)
      - [TOKEN](#token)
      - [ZONEID](#zoneid)
      - [RECORDID\&RECORDID6](#recordidrecordid6)
      - [URLPRE](#urlpre)
      - [URL\&URL6](#urlurl6)
      - [TYPE\&TYPE6](#typetype6)
      - [DOMAIN](#domain)
      - [TTL](#ttl)
      - [全局变量 currentIP](#全局变量-currentip)
      - [全局变量 previousIP](#全局变量-previousip)

# RouterOS Cloudflare DDNS

## 介绍

通过 `RouterOS` 脚本更新 `Cloudflare` `DDNS域名`记录值，配合ROS Scheduler以保证持续外部访问。

文本包含在 `RouterOS` 上配置上报公网 `IPv4` `IPv6` 到 `Cloudflare` 简要的过程，核心资产是自动化脚本。

## 声明

每个人所在网络环境不同，在我这里能用不等于在所有网络环境下都能用，所以严禁在生产环境或企业工作环境上使用本案。

我不是专业ROS脚本开发人员，做这些仅仅是基于兴趣爱好和自身需求，如有发现错误、改进方案、新的需求欢迎提交 **[Issues](https://github.com/caleee/routeros_cloudflare_ddns/issues)**，我们共同进步。

## 必要条件

+ 家庭宽带有公网IP地址
  + IPv4: 如果没有主动申请则默认无
  + IPv6:需要光猫开启IPv4&IPv6模式且ROS进行了相关配置

+ 默认适用于家庭宽带设置光猫桥接并使用RouterOS软/硬路由器拨号
+ 关于ROS新功能 IP CLOUD，官方提供的DDNS功能，脚本中可选使用 cloud 命令获取公网IP，比传统方法更加直接高效
  + 路由拨号的情况下也可以开启，也可能适配于下面几种情况，请自行测试
    + 使用光猫拨号、二级路由、旁路由
    + ROS安装在云主机上有弹性公网IP服务
+ RouterOS环境可以连接Cloudflare（公网权限、DNS解析正常）
+ 支持RouterOS 版本 v7.x（测试环境 v7.16.1 Stable） ，理论上支持未来版本及6.x，不要在生产环境或企业工作环境上使用本案
+ Cloudflare 账户、相关域名已托管、具有编辑相关域名权限的 API Token、相关域名A/AAAA记录已建立
  + 本案虚拟域名：`ddns.example.com` `Name:ddns`
    + `IPv4` `TYPE:A` `Content:123.123.123.123` `Proxy state:DNS only` `TTL:Auto` 
    + `IPv6` `TYPE:AAAA` `Content:1a::2a:3a:4a:5a:6a` `Proxy state:DNS only` `TTL:Auto` 

## 使用概述

+ 下载所需脚本模版

  + 三个版本自选，IPv4、IPv6、IPv4+IPv6

  + **注意：**首先确认环境拥有的公网IP地址类型，在选对应的脚本模版

    + 方法1

      浏览器打开 `https://ipw.cn/`  查看 IPv4 IPv6 后面是否有地址

      此方法只能说明你可以使用IPv4/IPv6浏览网页，还需要配合方法2/3进一步确认

    + 方法2

      RouterOS 命令行执行：

      ```ros_shell
      /ipv address print where interface=pppoe-out1
      # 结果中如果有 “100”开头的IPv4地址，那就是ISP运营商内部地址，不能算作公网地址
      
      /ipv6 address print where interface=pppoe-out1
      # 结果中查看是否有 “2” 开头的IPv6地址，“f” 开头的是本地地址
      ```

    + 方法3

      RouterOS版本有`/ip cloud`功能的，命令行执行：

      ```ros_shell
      :put [/ip cloud get public-address]
      # 直接获取拨号网卡的IPv4地址
      
      :put [/ip cloud get public-address-ipv6]
      # 直接获取拨号网卡的IPv6地址，无输出则没有ipv6
      ```

+ 修改脚本变量

+ winbox中新建 ROS Script （System-Script）或放在 /system scripts

+ winbox中新建计划任务（System-Scheduler）或命令行 

  ```ros_shell
  /system scheduler
  add comment="cloudflare ddns ipv4 update" interval=5m name=ddns-cf_ipv4 on-event="/system script run ddns-cf-ipv4"
  
  # comment内容随意，interval是执行周期（5分钟执行一次），name内容随意，on-event需要对应的脚本名称
  ```

## 脚本内容解析

+ 通过命令行获取当前公网IP
+ 比对上次获取的公网IP，如果有变化则请求Cloudflare API 修改记录值
+ 每一步会有log打印（winbox-log），机翻的英文log，应该都能看懂，凑活看吧

### 变量

#### DEBUG

+ 可选值为"on"与其他，当值为"on"时，ROS的日志中会打印 $currentIP $previousIP 的值，也就是当前IP和上次的IP

+ 两个值不正常显示则需要根据其他log找到可能出现报错的位置修改重新调试

#### CLOUD

+ 可选值为"yes"与其他，默认关闭

+ 对应使用ROS的 /IP CLOUD 的获取IP的功能，当参数为"yes"时利用`/ip cloud get`命令行获取公网IP
+ 旧版本的ROS没有CLOUD功能，x86版也没有（道听途说）

#### INTERFACE

+ 默认值为"pppoe-out1"，用于拨号的网卡名称

  + winbox中 PPP- Interface-name值

  + 命令行 name值

    ```ros_shell
    /interface/pppoe-client/print value-list
    ```

+ 或者具有公网IP地址的网卡名称

#### TOKEN

+ Cloudflare中建立的具有编辑相关域名权限的 API Token（编辑区域 DNS API 令牌）

#### ZONEID

+ Cloudflare托管的区域DNS ID，例如`example.com`，在bash终端使用curl命令行获取

  ```bash
  curl -X GET "https://api.cloudflare.com/client/v4/zones?name=<改成你的域名>" \
       -H "Authorization: Bearer <改成你的APIToken>"
       
  # 提取出第一行的 "id" 字段的值作为 Zone ID
  ```

+ 如果你的终端带有 jq 工具使用以下命令直接打印出 Zone ID

  ```bash
  curl -X GET "https://api.cloudflare.com/client/v4/zones?name=<改成你的域名>" \
       -H "Authorization: Bearer <改成你的APIToken>" | jq -r '.result[0].id'
  ```

#### RECORDID&RECORDID6

+ Cloudflare托管的已建立域名A/AAAA记录的域名ID，例如`ddns.example.com`，在bash终端使用curl命令行获取

  ```bash
  curl -X GET "https://api.cloudflare.com/client/v4/zones/<改为上一步获取的ZoneID>/dns_records?name=<改为你准备使用的DDNS域名>&type=<这里改为A或AAAA，分别对应获取ipv4记录与ipv6记录>" \
       -H "Authorization: Bearer <改成你的APIToken>"
       
  # 提取出第一行的 "id" 字段的值作为 Record ID
  ```

+ 如果你的终端带有 jq 工具使用以下命令直接打印出 Record ID

  ```bash
  curl -X GET "https://api.cloudflare.com/client/v4/zones/<改为上一步获取的ZoneID>/dns_records?name=<改为你准备使用的DDNS域名>&type=<这里改为A或AAAA，分别对应获取ipv4记录与ipv6记录>" \
       -H "Authorization: Bearer <改成你的APIToken>" | jq -r '.result[0].id'
  ```

#### URLPRE

+ 固定值 "https://api.cloudflare.com/client/v4/zones/"

#### URL&URL6

+ URL 前缀与 Zone ID、Record ID合成的访问地址，其值随着ZONEID、RECORDID&RECORDID6的改变而改变

#### TYPE&TYPE6

+ Record类型，固定值，A代表IPv4类型，AAAA代表IPv6类型

#### DOMAIN

+ 准备用来做DDNS的域名，例如`ddns.example.com`

#### TTL

+ DNS 记录的生存时间，脚本的默认值设置为"1"，这是 Cloudflare 允许的最小值，可以理解为"自动"，不代表 1s
+ 可以改成其他值，例如 "120" （2min）

#### 全局变量 currentIP

+ 通过命令行获取当前公网IP值，也可以设置成local变量

#### 全局变量 previousIP

+ 上次记录的公网IP值，脚本外生效，用于比对 currentIP 只有差异情况才会对接 API 修改记录值，防止无效请求，必须设置成全局变量

---

