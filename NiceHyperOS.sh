#!/bin/bash

# 定义一个函数来执行删除操作
remove_files() {
    for file in $1; do
        if find . -iname "$file" | grep -q .; then
            echo "正在删除 $file ..."
            find . -iname "$file" | xargs rm -vrf
            echo "$file 已被删除。"
        else
            echo "未找到 $file。"
        fi
    done
}

# 定义一个函数来执行 Deodex 操作
deodex() {
    find . -name "oat" | xargs rm -vrf
    find . -name "*.art" -not \( -name "boot-framework.art" -o -name "这是一个举例" \) | xargs rm -vrf
    find . -name "*.oat" -not \( -name "boot-framework.oat" \) | xargs rm -vrf
    find . -name "*.vdex" -not \( -name "boot-framework.vdex" \) | xargs rm -vrf
    find . -name "*.odex" | xargs rm -vrf
}

# 定义一个函数来执行所有的删除操作
remove_all() {
    for opt in "${options_order[@]}"; do
        if [ "$opt" != "Deodex" ] && [ "$opt" != "删除所有" ] && [ "$opt" != "退出" ]; then
            echo "你选择了 $opt"
            remove_files "${options[$opt]}"
        fi
    done
}

# 定义一个数组来存储所有的操作的顺序
options_order=("删除小爱翻译" "删除小爱语音唤醒" "删除小爱助手" "删除小爱通话" "删除小米互联互通服务的设备 ROOT 验证" "删除小米浏览器" "删除小米音乐" "删除小米视频" "删除小米游戏中心" "删除小米钱包" "删除快应用" "删除 Joyose 云控" "删除分析" "删除智能服务" "删除自带输入法" "删除传送门" "删除智能助理" "删除搜索功能" "删除悬浮球" "删除应用商店" "删除锁屏服务" "删除服务与反馈" "删除系统更新" "删除家人守护" "删除 MIUI 包应用安装器" "删除小米商城" "删除小米健康" "Deodex" "删除所有" "退出")

# 定义一个关联数组来存储每个操作对应的文件或目录的名称
declare -A options
options=(
    ["删除小爱翻译"]="AiAsstVision*"
    ["删除小爱语音唤醒"]="VoiceTrigger"
    ["删除小爱助手"]="VoiceAssistAndroidT"
    ["删除小爱通话"]="MIUIAiasstService"
    ["删除小米互联互通服务的设备 ROOT 验证"]="MiTrustService"
    ["删除小米浏览器"]="MIUIBrowser"
    ["删除小米音乐"]="MIUIMusic*"
    ["删除小米视频"]="MIUIVideo*"
    ["删除小米游戏中心"]="MIUIGameCenter"
    ["删除小米钱包"]="MIpay"
    ["删除快应用"]="HybridAccessory"
    ["删除 Joyose 云控"]="Joyose"
    ["删除分析"]="AnalyticsCore"
    ["删除智能服务"]="MSA*"
    ["删除自带输入法"]="SogouInput com.iflytek.inputmethod.miui BaiduIME"
    ["删除传送门"]="MIUIContentExtension*"
    ["删除智能助理"]="MIUIPersonalAssistant*"
    ["删除搜索功能"]="MIUIQuickSearchBox"
    ["删除悬浮球"]="MIUITouchAssistant*"
    ["删除应用商店"]="MIUISuperMarket*"
    ["删除锁屏服务"]="MIGalleryLockscreen*"
    ["删除服务与反馈"]="MIService"
    ["删除系统更新"]="Updater"
    ["删除家人守护"]="MIUIgreenguard"
    ["删除 MIUI 包应用安装器"]="MIUIPackageInstaller"
    ["删除小米商城"]="MiShop"
    ["删除小米健康"]="Health"
    ["Deodex"]=""
    ["删除所有"]=""
    ["退出"]=""
)

while true; do
echo "=============================="
echo "  请选择要执行的操作："
echo "=============================="

	PS3="请输入你的选择："
    select opt in "${options_order[@]}"; do
	echo ""
        case $opt in
            "退出")
                echo "退出脚本"
                exit 0
                ;;
            "Deodex")
                echo "你选择了 Deodex"
                deodex
                break
                ;;
            "删除所有")
                echo "你选择了 删除所有"
                remove_all
                break
                ;;
            *)
                echo "你选择了 $opt"
                IFS=' ' read -ra ADDR <<< "${options[$opt]}"
                for i in "${ADDR[@]}"; do
                    remove_files "$i"
                done
                break
                ;;
        esac
    done
done
