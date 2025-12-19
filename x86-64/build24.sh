#!/bin/bash
# Log file for debugging
source shell/custom-packages.sh
echo "第三方软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "编译固件大小为: $PROFILE MB"
echo "Include Docker: $INCLUDE_DOCKER"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # ============= 同步第三方插件库==============
  # 同步第三方软件仓库run/ipk
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/yndzm/store.git /tmp/store-run-repo

  # 拷贝 run/x86 下所有 run 文件和ipk文件 到 extra-packages 目录
  mkdir -p /home/build/immortalwrt/extra-packages
  cp -r /tmp/store-run-repo/run/x86/* /home/build/immortalwrt/extra-packages/

  echo "✅ Run files copied to extra-packages:"
  ls -lh /home/build/immortalwrt/extra-packages/*.run
  # 解压并拷贝ipk到packages目录
  sh shell/prepare-packages.sh
  ls -lah /home/build/immortalwrt/packages/
fi

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."

# ============= imm仓库内的插件==============
# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
# PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
# PACKAGES="$PACKAGES luci-theme-argon"
# PACKAGES="$PACKAGES luci-app-argon-config"
# PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
# PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-passwall-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
# PACKAGES="$PACKAGES luci-app-smartdns"
# PACKAGES="$PACKAGES luci-i18n-smartdns-zh-cn"
# PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
# PACKAGES="$PACKAGES openssh-sftp-server"
# PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"
# PACKAGES="$PACKAGES adguardhome"
# 文件管理器
# PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"
# 静态文件服务器dufs(推荐)
# PACKAGES="$PACKAGES luci-i18n-dufs-zh-cn"
# ======== shell/custom-packages.sh =======
# 合并imm仓库以外的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"


# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ [构建逻辑] 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    if [ -f extra-packages/temp-unpack/clash_meta ]; then
        cp extra-packages/temp-unpack/clash_meta files/etc/openclash/core/clash_meta
    else
        echo "⚠️ [警告] 缺少 clash_meta 内核,跳过复制,你应该确保extra-packages目录下有相关run文件"
    fi
else
    echo "⚪️ [构建逻辑] 未选择 luci-app-openclash"
    [ -d files/etc/openclash ] && rm -rf files/etc/openclash
fi


# 若构建luci-app-adguardhome 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-adguardhome"; then
    echo "✅ [构建逻辑] 已选择 luci-app-adguardhome，添加 AdGuardHome core"
    if [ -f extra-packages/temp-unpack/AdGuardHome/AdGuardHome ]; then
        cp extra-packages/temp-unpack/AdGuardHome/AdGuardHome files/usr/bin/AdGuardHome
    else
        echo "⚠️ [警告] 缺少 AdGuardHome内核,跳过复制,你应该确保extra-packages目录下有相关run文件"
    fi
else
    echo "⚪️ [构建逻辑] 未选择 luci-app-adguardhome"
    [ -f files/usr/bin/AdGuardHome ] && rm -f files/usr/bin/AdGuardHome
fi
# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PROFILE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
