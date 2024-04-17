#!/bin/bash

function decompile_and_modify() {
    local apktool_jar_path="bin/all/apktool/apktool_2.9.3.jar"
    local jarname="$1"  # 将 .jar 文件名作为参数传递给函数

    find "$onepath" -name "$jarname" | while read -r jarfile
    do
        echo "正在反编译 $jarfile ..."
        java -jar "$apktool_jar_path" d -f "$jarfile" -o "${jarfile%.jar}"
        echo "反编译完成，正在删除 $jarfile ..."
        rm "$jarfile"

        find "${jarfile%.jar}" -name '*.smali' | while read -r smalifile
        do
            echo "正在搜寻 $smalifile ..."
            sed -i 's/invoke-static {\(.*\)}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I/const\/4 \1, 0x0/g' "$smalifile"
        done
        echo "修改完成"
        echo "正在重新编译 ${jarfile%.jar} ..."
        java -jar "$apktool_jar_path" b "${jarfile%.jar}" -o "${jarfile%.jar}_new.jar"
        echo "重新编译完成，新的 jar 文件是 ${jarfile%.jar}_new.jar"

        echo "正在移动新的 jar 文件到原文件所在的目录 ..."
        mv "${jarfile%.jar}_new.jar" "$jarfile"
        echo "移动完成，新的 jar 文件现在位于 $jarfile"

        echo "正在删除反编译的文件夹 ..."
 #       rm -r "${jarfile%.jar}"
        echo "删除完成，反编译的文件夹已被删除"
    done
}

# 定义一个函数来解码 csc
decode_csc() {
    local script_dir=$(dirname "$0")
    local omc_decoder_path="$script_dir/bin/samsung/csc_tool/omc-decoder.jar"
    local input_file
    local output_file
    for file in "cscfeature.xml" "customer_carrier_feature.json"; do
        find $onepath -name "$file" -print | while read -r filepath; do
            echo "找到文件：$filepath"
            echo "正在解码 $file ..."
            input_file="$filepath"
            output_file="${filepath%.*}_decoded.${filepath##*.}"
            java -jar $omc_decoder_path -i $input_file -o $output_file
            rm -v $input_file  # 删除原始文件
        done
    done
}

# 定义一个函数来编码 csc
encode_csc() {
    local script_dir=$(dirname "$0")
    local omc_decoder_path="$script_dir/bin/samsung/csc_tool/omc-decoder.jar"
    local input_file
    local output_file
    local original_file
    for file in "cscfeature_decoded.xml" "customer_carrier_feature_decoded.json"; do
        find $onepath -name "$file" -print | while read -r filepath; do
            echo "找到文件：$filepath"
            echo "正在编码 $file ..."
            input_file="$filepath"
            output_file="${filepath/_decoded/}"
            java -jar $omc_decoder_path -e -i $input_file -o $output_file
            rm -v $input_file  # 删除解码的文件
        done
    done
}


block_app_installer() {
    for file in $1; do
        find $onepath -iname "$file" -print0 | while IFS= read -r -d '' file_path; do
            if [ -f "$file_path" ]; then
                echo "正在屏蔽 $file ..."
                > "$file_path"
                oat_dir="$(dirname "$file_path")/oat"
                if [ -d "$oat_dir" ]; then
                    echo "正在删除 $oat_dir ..."
                    rm -r "$oat_dir"
                fi
            else
                echo "未找到 $file"
            fi
        done
    done
}


# 定义一个函数来执行删除操作
remove_files() {
    for file in $1; do
        if find $onepath -iname "$file" | grep -q .; then
            echo "正在删除 $file ..."
            find $onepath -iname "$file" | xargs rm -vrf
        else
            echo "未找到 $file"
        fi
    done
}

# 定义一个函数来执行 Deodex 操作
deodex() {
    local found=false
    for file in oat "*.art" "*.oat" "*.vdex" "*.odex" "*.fsv_meta"; do
        if find $onepath -name "$file" | grep -q .; then
            found=true
            echo "正在删除 $file ..."
            find $onepath -name "$file" -not \( -name "boot-framework.*" -o -name "boot.*" \) | xargs rm -vrf
        fi
    done
    if [ "$found" = false ]; then
        echo "没有与 odex 有关的文件可删除"
    fi
}

# 定义一个函数来执行 仅 services.jar deodex 操作
services_jar_dex() {
    local found=false
    for file in "services.art" "services.odex" "services.vdex" "services.*.fsv_meta" "services.jar.bprof" "services.jar.prof" ; do
        if find $onepath -name "$file" | grep -q .; then
            found=true
            echo "正在删除 $file ..."
            find $onepath -name "$file" | xargs rm -vrf
        fi
    done
    if [ "$found" = false ]; then
        echo "没有与 services.jar 的 odex 有关的文件可删除"
    fi
}

# 定义一个函数来执行所有的删除操作
remove_all() {
    for opt in "${options_order[@]}"; do
        if [ "$opt" != "Deodex" ] && [ "$opt" != "仅 services.jar deodex" ] && [ "$opt" != "删除所有" ] && [ "$opt" != "退出" ] && [ "$opt" != "调用原生安装器" ] && [ "$opt" != "解码 csc" ] && [ "$opt" != "编码 csc" ]; then
            echo "你选择了 $opt"
            remove_files "${options[$opt]}"
        fi
    done
}

echo "当前所处目录：$(pwd)"
echo ""
while true; do
    echo "请输入工作目录："
    read onepath
    if [[ "$onepath" == /home* || "$onepath" == /mnt* || "$onepath" == /storage/emulated/0* ]]; then
        if [ -d "$onepath" ]; then
            echo "你输入的路径是：$onepath"
	    echo ""
            break
        else
            echo "路径不存在，请重新输入。"	
	    echo ""
        fi
    else
        echo "安全保护，请重新输入"
	echo ""
    fi
done

# 定义一个数组来存储所有的 ROM
rom_brands=("HyperOS" "OneUI" "退出")

brand_selected=false
while true; do
    echo "=============================="
    echo "  请选择要修改的 ROM："
    echo "=============================="
    PS3="请输入你的选择："
    select brand in "${rom_brands[@]}"; do
        case $brand in
            "HyperOS")
                echo "你选择了 HyperOS"
                options_order=("删除小爱翻译" "删除小爱语音唤醒" "删除小爱助手" "删除小爱通话" "删除小米互联互通服务的设备 ROOT 验证" "删除小米浏览器" "删除小米音乐" "删除小米视频" "删除小米游戏中心" "删除小米钱包" "删除快应用" "删除 Joyose 云控" "删除分析" "删除智能服务" "删除自带输入法" "删除传送门" "删除智能助理" "删除搜索功能" "删除悬浮球" "删除应用商店" "删除锁屏服务" "删除服务与反馈" "删除系统更新" "删除家人守护" "删除小米商城" "删除小米健康" "更改 Android 13 的校验机制" "调用原生安装器" "仅 services.jar deodex" "Deodex" "删除所有" "退出")
                declare -A options
                options=(
                    ["删除小爱翻译"]="AiAsstVision*"
                    ["删除小爱语音唤醒"]="VoiceTrigger"
                    ["删除小爱助手"]="VoiceAssistAndroidT"
                    ["删除小爱通话"]="MIUIAiasstService"
                    ["删除小米互联互通服务的设备 ROOT 验证"]="MiTrustService"
                    ["删除小米浏览器"]="MIUIBrowser MiBrowserGlobal"
                    ["删除小米音乐"]="MIUIMusic*"
                    ["删除小米视频"]="MIUIVideo*"
                    ["删除小米游戏中心"]="MIUIGameCenter"
                    ["删除小米钱包"]="MIpay"
                    ["删除快应用"]="HybridAccessory HybridPlatform"
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
                    ["删除小米商城"]="MiShop"
                    ["删除小米健康"]="Health"
                    ["更改 Android 13的校验机制"]=""
                    ["调用原生安装器"]=""
                    ["仅 services.jar deodex"]=""
                    ["Deodex"]=""
                    ["删除所有"]=""
                    ["退出"]=""
                )
                brand_selected=true
                break
                ;;
            "OneUI")
                echo "你选择了 OneUI"
options_order=("删除三星浏览器组件" "删除开机验证" "删除 Rec 恢复为官方" "解码 csc" "编码 csc" "仅 services.jar deodex" "Deodex" "删除所有" "退出")
declare -A options
                options=(
                    ["删除三星浏览器组件"]="SBrowser SBrowserIntelligenceService"
                    ["删除开机验证"]="ActivationDevice_V2"
                    ["删除 Rec 恢复为官方"]="recovery-from-boot.p"
                    ["解码 csc"]=""
                    ["编码 csc"]=""
                    ["仅 services.jar deodex"]=""
                    ["Deodex"]=""
                    ["删除所有"]=""
                    ["退出"]=""
)
                brand_selected=true
                break
                ;;
            "退出")
                echo "退出脚本"
                exit 0
                ;;
            *)
                echo "无效的选择：$REPLY"
                ;;
        esac
    done
    if [ "$brand_selected" = true ]; then
        break
    fi
done

while true; do
    echo ""
    echo "=============================="
    echo "  请选择要执行的操作："
    echo "=============================="
    PS3="请输入你的选择（多个选择请用逗号分隔，例如：1,3,5）："
    select opt in "${options_order[@]}"; do
        IFS=',' read -ra selections <<< "$REPLY"
        decode_selected=false
        encode_selected=false
        deodex_selected=false
        services_jar_dex_selected=false
        for selection in "${selections[@]}"; do
            # 检查选择是否有效
            if [[ $selection -lt 1 || $selection -gt ${#options_order[@]} ]]; then
                echo "无效的选择：$selection"
                continue
            fi
            opt=${options_order[$((selection-1))]}
            # 如果在多选模式下选择了"退出"，则忽略"退出"
            if [[ ${#selections[@]} -gt 1 && "$opt" == "退出" ]]; then
                echo "在多选择下，无法退出。"
                continue
            fi
            if [ "$opt" == "解码 csc" ]; then
                decode_selected=true
            fi
            if [ "$opt" == "编码 csc" ]; then
                encode_selected=true
            fi
            if [ "$opt" == "Deodex" ]; then
                deodex_selected=true
            fi
            if [ "$opt" == "仅 services.jar deodex" ]; then
                services_jar_dex_selected=true
            fi
        done
        if [ "$decode_selected" = true ] && [ "$encode_selected" = true ]; then
            echo "无效的选择：不能同时选择解码和编码"
            continue
        fi
        if [ "$deodex_selected" = true ] && [ "$services_jar_dex_selected" = true ]; then
            echo "无效的选择：不能同时选择 Deodex 和 仅 services.jar deodex"
            continue
        fi
        for selection in "${selections[@]}"; do
            opt=${options_order[$((selection-1))]}
            case $opt in
                "解码 csc")
                    echo "你选择了 解码 csc"
                    decode_csc
                    ;;
                "编码 csc")
                    echo "你选择了 编码 csc"
                    encode_csc
                    ;;
                "更改 Android 13 的校验机制")
                    echo "更改 Android 13 的校验机制"
                    decompile_and_modify "services.jar"
                    ;;
                "调用原生安装器")
                    echo "你选择了 调用原生安装器"
                    block_app_installer "MIUIPackageInstaller.apk"
                    ;;
                "Deodex")
                    echo "你选择了 Deodex"
                    deodex
                    ;;
                "仅 services.jar deodex")
                    echo "你选择了 仅 services.jar deodex"
                    services_jar_dex
                    ;;
                "删除所有")
                    if [[ ${#selections[@]} -gt 1 ]]; then
                        echo "删除所有在多选择中被禁用"
                    else
                        echo "你选择了 删除所有"
                        remove_all
                    fi
                    ;;
                "退出")
                    echo "退出脚本"
                    exit 0
                    ;;
                *)
                    echo "你选择了 $opt"
                    remove_files "${options[$opt]}"
                    ;;
            esac
        done
        break
    done
done
