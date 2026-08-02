#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY
#
# CloseWRT-CI 本地编译脚本
# 用法: ./build-local.sh [配置名称]
# 配置名称: MT7981, MT7986, TEST (默认: MT7981)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRT_DIR="/media/ye/sd240/900/immortalwrt-mt798x-6.6"

# 编译配置
WRT_CONFIG="${1:-MT7981}"
WRT_THEME="aurora"
WRT_NAME="CWRT"
WRT_SSID="CWRT"
WRT_WORD="12345678"
WRT_IP="192.168.10.1"
WRT_PW="无"
WRT_DATE="$(TZ=UTC-8 date +"%y.%m.%d-%H.%M.%S")"
WRT_MARK="local"

echo "=========================================="
echo "CloseWRT-CI 本地编译脚本"
echo "=========================================="
echo "配置: $WRT_CONFIG"
echo "源码路径: $WRT_DIR"
echo "主题: $WRT_THEME"
echo "日期: $WRT_DATE"
echo "=========================================="

# 检查源码目录是否存在
if [ ! -d "$WRT_DIR" ]; then
    echo "错误: 源码目录不存在! $WRT_DIR"
    exit 1
fi

cd "$WRT_DIR"

# 检查配置文件是否存在
if [ ! -f "$SCRIPT_DIR/Config/$WRT_CONFIG.txt" ]; then
    echo "错误: 配置文件不存在! $SCRIPT_DIR/Config/$WRT_CONFIG.txt"
    exit 1
fi

# 检查是否已经执行过 feeds
if [ ! -d "./feeds" ] || [ ! -f "./feeds.tmp" ]; then
    echo "执行 feeds update & install..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    touch feeds.tmp
fi

# 应用自定义包
echo "应用自定义包..."
cd "$WRT_DIR/package/"
if [ -f "$SCRIPT_DIR/Scripts/Packages.sh" ]; then
    bash "$SCRIPT_DIR/Scripts/Packages.sh"
fi
if [ -f "$SCRIPT_DIR/Scripts/Handles.sh" ]; then
    bash "$SCRIPT_DIR/Scripts/Handles.sh"
fi

cd "$WRT_DIR"

# 应用配置
echo "应用配置..."
if [ "$WRT_CONFIG" = "TEST" ]; then
    cat "$SCRIPT_DIR/Config/$WRT_CONFIG.txt" > .config
else
    cat "$SCRIPT_DIR/Config/$WRT_CONFIG.txt" "$SCRIPT_DIR/Config/GENERAL.txt" > .config
fi

# 运行设置脚本
if [ -f "$SCRIPT_DIR/Scripts/Settings.sh" ]; then
    WRT_THEME="$WRT_THEME" WRT_NAME="$WRT_NAME" WRT_SSID="$WRT_SSID" \
    WRT_WORD="$WRT_WORD" WRT_IP="$WRT_IP" WRT_PW="$WRT_PW" \
    WRT_DATE="$WRT_DATE" WRT_MARK="$WRT_MARK" \
    bash "$SCRIPT_DIR/Scripts/Settings.sh"
fi

# 生成 defconfig
echo "生成 defconfig..."
make defconfig -j$(nproc)

# 清理
echo "清理..."
make clean -j$(nproc) 2>/dev/null || true

# 下载包
echo "下载包..."
make download -j$(nproc) 2>/dev/null || make download -j1 V=s

# 编译固件
echo "开始编译固件..."
echo "=========================================="
make -j$(nproc) 2>&1 | tee build.log || make -j1 V=s 2>&1 | tee -a build.log

echo "=========================================="
echo "编译完成!"
echo "输出目录: $WRT_DIR/bin/targets/"
echo "编译日志: $WRT_DIR/build.log"
echo "=========================================="