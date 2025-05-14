#!/bin/sh

LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE

# 设置防火墙：允许LAN区域接收所有流量（含IPv6）
uci set firewall.@zone[1].input='ACCEPT'
uci set firewall.@zone[1].network='lan'
uci set firewall.@zone[1].family='any'  # 明确支持IPv6

# 设置主机名映射
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"

# 自动检测物理网卡数量
count=0
ifnames=""
for iface in /sys/class/net/*; do
  iface_name=$(basename "$iface")
  if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
    count=$((count + 1))
    ifnames="$ifnames $iface_name"
  fi
done
ifnames=$(echo "$ifnames" | awk '{$1=$1};1')

# 网络设置
if [ "$count" -eq 1 ]; then
   uci set network.lan.proto='dhcp'
else
   wan_ifname=$(echo "$ifnames" | awk '{print $1}')
   lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)

   # WAN设置
   uci set network.wan=interface
   uci set network.wan.device="$wan_ifname"
   uci set network.wan.proto='pppoe'
   uci set network.wan.username='02705250469'
   uci set network.wan.password='250469'
   uci set network.wan.peerdns='1'
   uci set network.wan.auto='1'

   # IPv6设置（WAN6）
   uci set network.wan6=interface
   uci set network.wan6.device="$wan_ifname"
   uci set network.wan6.proto='dhcpv6'
   uci set network.wan6.auto='1'

   # LAN设置
   uci set network.lan.proto='static'
   uci set network.lan.ipaddr='192.168.2.1'
   uci set network.lan.netmask='255.255.255.0'

   # 更新br-lan绑定网口
   section=$(uci show network | awk -F '[.=]' '/\.@?device\[\d+\]\.name=.br-lan.$/ {print $2; exit}')
   if [ -n "$section" ]; then
      uci -q delete "network.$section.ports"
      for port in $lan_ifnames; do
         uci add_list "network.$section.ports"="$port"
      done
   else
      echo "warning: cannot find br-lan section" >> $LOGFILE
   fi
fi

# 设置网页终端和SSH可用
uci delete ttyd.@ttyd[0].interface
uci set dropbear.@dropbear[0].Interface=''

# 启用IPv6相关服务
uci set dhcp.lan.dhcpv6='server'
uci set dhcp.lan.ra='server'
uci set dhcp.lan.ra_management='1'
uci set dhcp.lan.ndp='disabled'

# 修改系统信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="Compiled by aixinyin"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

uci commit
exit 0
