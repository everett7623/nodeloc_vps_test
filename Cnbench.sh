#!/bin/bash

# 定义版本
CURRENT_VERSION="2025-01-21 v1.2.7" # 最新版本号
SCRIPT_URL="https://ghfast.top/https://raw.githubusercontent.com/nodeloc/nodeloc_vps_test/main/Nlbench.sh"
VERSION_URL="https://ghfast.top/https://raw.githubusercontent.com/nodeloc/nodeloc_vps_test/main/version.sh"
CLOUD_SERVICE_BASE="https://bench.nodeloc.cc"

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# 定义渐变颜色数组
colors=(
    '\033[38;2;0;255;0m'    # 绿色
    '\033[38;2;64;255;0m'
    '\033[38;2;128;255;0m'
    '\033[38;2;192;255;0m'
    '\033[38;2;255;255;0m'  # 黄色
)

# 更新脚本
update_scripts() {
    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│           NodeLoc VPS 测试脚本          │${NC}"
    echo -e "${BLUE}│               版本检查                  │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"

    REMOTE_VERSION=$(curl -s $VERSION_URL | tail -n 1 | grep -oP '(?<=#\s)[\d-]+\sv[\d.]+(?=\s-)')
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}✖ 无法获取远程版本信息。请检查您的网络连接。${NC}"
        return 1
    fi

    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│               版本历史                  │${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}  当前版本: ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}  版本历史:${NC}"
    curl -s $VERSION_URL | grep -oP '(?<=#\s)[\d-]+\sv[\d.]+(?=\s-)' | 
    while read version; do
        if [ "$version" = "$CURRENT_VERSION" ]; then
            echo -e "  ${GREEN}▶ $version ${NC}(当前版本)"
        else
            echo -e "    $version"
        fi
    done
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"

    if [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
        echo -e "\n${YELLOW}发现新版本: ${GREEN}$REMOTE_VERSION${NC}"
        echo -e "${BLUE}正在更新...${NC}"
        
        if curl -s -o /tmp/NLbench.sh $SCRIPT_URL; then
            NEW_VERSION=$(grep '^CURRENT_VERSION=' /tmp/NLbench.sh | cut -d'"' -f2)
            if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
                sed -i "s/^CURRENT_VERSION=.*/CURRENT_VERSION=\"$NEW_VERSION\"/" "$0"
                
                if mv /tmp/NLbench.sh "$0"; then
                    chmod +x "$0"
                    echo -e "${GREEN}┌─────────────────────────────────────────┐${NC}"
                    echo -e "${GREEN}│            脚本更新成功！               │${NC}"
                    echo -e "${GREEN}└─────────────────────────────────────────┘${NC}"
                    echo -e "${YELLOW}新版本: ${GREEN}$NEW_VERSION${NC}"
                    echo -e "${YELLOW}正在重新启动脚本以应用更新...${NC}"
                    sleep 3
                    exec bash "$0"
                else
                    echo -e "${RED}✖ 无法替换脚本文件。请检查权限。${NC}"
                    return 1
                fi
            else
                echo -e "${GREEN}✔ 脚本已是最新版本。${NC}"
            fi
        else
            echo -e "${RED}✖ 下载新版本失败。请稍后重试。${NC}"
            return 1
        fi
    else
        echo -e "\n${GREEN}✔ 脚本已是最新版本。${NC}"
    fi
    
    echo -e "${BLUE}┌─────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│            更新检查完成                 │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"
}

# 检查 root 权限并获取 sudo 权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "此脚本需要 root 权限运行。"
        if ! sudo -v; then
            echo "无法获取 sudo 权限，退出脚本。"
            exit 1
        fi
        echo "已获取 sudo 权限。"
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type=$ID
    elif type lsb_release >/dev/null 2>&1; then
        os_type=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        os_type=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        os_type="debian"
    elif [ -f /etc/fedora-release ]; then
        os_type="fedora"
    elif [ -f /etc/centos-release ]; then
        os_type="centos"
    else
        os_type=$(uname -s)
    fi
    os_type=$(echo $os_type | tr '[:upper:]' '[:lower:]')
    echo "检测到的操作系统: $os_type"
}

# 更新系统
update_system() {
    detect_os
    if [ $? -ne 0 ]; then
        echo -e "${RED}无法检测操作系统。${NC}"
        return 1
    fi
    case "${os_type,,}" in
        ubuntu|debian|linuxmint|elementary|pop)
            update_cmd="apt-get update"
            upgrade_cmd="apt-get upgrade -y"
            clean_cmd="apt-get autoremove -y"
            ;;
        centos|rhel|fedora|rocky|almalinux|openeuler)
            if command -v dnf &>/dev/null; then
                update_cmd="dnf check-update"
                upgrade_cmd="dnf upgrade -y"
                clean_cmd="dnf autoremove -y"
            else
                update_cmd="yum check-update"
                upgrade_cmd="yum upgrade -y"
                clean_cmd="yum autoremove -y"
            fi
            ;;
        opensuse*|sles)
            update_cmd="zypper refresh"
            upgrade_cmd="zypper dup -y"
            clean_cmd="zypper clean -a"
            ;;
        arch|manjaro)
            update_cmd="pacman -Sy"
            upgrade_cmd="pacman -Syu --noconfirm"
            clean_cmd="pacman -Sc --noconfirm"
            ;;
        alpine)
            update_cmd="apk update"
            upgrade_cmd="apk upgrade"
            clean_cmd="apk cache clean"
            ;;
        gentoo)
            update_cmd="emerge --sync"
            upgrade_cmd="emerge -uDN @world"
            clean_cmd="emerge --depclean"
            ;;
        cloudlinux)
            update_cmd="yum check-update"
            upgrade_cmd="yum upgrade -y"
            clean_cmd="yum clean all"
            ;;
        *)
            echo -e "${RED}不支持的 Linux 发行版: $os_type${NC}"
            return 1
            ;;
    esac
    
    echo -e "${YELLOW}正在更新系统...${NC}"
    sudo $update_cmd
    if [ $? -eq 0 ]; then
        sudo $upgrade_cmd
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}系统更新完成。${NC}"
            echo -e "${YELLOW}正在清理系统...${NC}"
            sudo $clean_cmd
            echo -e "${GREEN}系统清理完成。${NC}"
            # 检查是否需要重启
            if [ -f /var/run/reboot-required ]; then
                echo -e "${YELLOW}系统更新需要重启才能完成。请在方便时重启系统。${NC}"
            fi
            return 0
        fi
    fi
    echo -e "${RED}系统更新失败。${NC}"
    return 1
}

# 定义支持的操作系统类型
SUPPORTED_OS=("ubuntu" "debian" "linuxmint" "elementary" "pop" "centos" "rhel" "fedora" "rocky" "almalinux" "openeuler" "opensuse" "sles" "arch" "manjaro" "alpine" "gentoo" "cloudlinux")

install_dependencies() {
    echo -e "${YELLOW}正在检查并安装必要的依赖项...${NC}"
    
    # 确保 os_type 已定义
    if [ -z "$os_type" ]; then
        detect_os
    fi
    
    # 更新系统
    update_system || echo -e "${RED}系统更新失败。继续安装依赖项。${NC}"
    
    # 安装依赖
    local dependencies=("curl" "wget" "iperf3" "bc")
    
    # 检查是否为支持的操作系统
    if [[ ! " ${SUPPORTED_OS[@]} " =~ " ${os_type} " ]]; then
        echo -e "${RED}不支持的操作系统: $os_type${NC}"
        return 1
    fi
    
    case "${os_type,,}" in
        debian|ubuntu)
            export DEBIAN_FRONTEND=noninteractive  # 禁用交互
            echo "iperf3 iperf3/autostart boolean false" | sudo debconf-set-selections
            install_cmd="apt-get install -yq"
            sudo apt-get update -yq
            ;;
        centos|rhel|fedora)
            install_cmd="dnf install -y"
            sudo dnf makecache
            ;;
        alpine)
            install_cmd="apk add --no-cache"
            ;;
        gentoo)
            install_cmd="emerge --quiet"
            ;;
        arch|manjaro)
            install_cmd="pacman -S --noconfirm"
            sudo pacman -Sy --noconfirm
            ;;
        *)
            echo -e "${RED}未知的包管理器。请手动安装依赖项。${NC}"
            return 1
            ;;
    esac

    # 安装依赖项
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${YELLOW}正在安装 $dep...${NC}"
            if ! sudo $install_cmd "$dep"; then
                echo -e "${RED}无法安装 $dep。请手动安装此依赖项。${NC}"
            fi
        else
            echo -e "${GREEN}$dep 已安装。${NC}"
        fi
    done
    
    echo -e "${GREEN}依赖项检查和安装完成。${NC}"
}

# 获取IP地址和ISP信息
ip_address_and_isp() {
    ipv4_address=$(curl -s --max-time 5 ipv4.ip.sb)
    if [ -z "$ipv4_address" ]; then
        ipv4_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    fi

    ipv6_address=$(curl -s --max-time 5 ipv6.ip.sb)
    if [ -z "$ipv6_address" ]; then
        ipv6_address=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^::1' | grep -v '^fe80' | head -n1)
    fi

    # 获取ISP信息
    isp_info=$(curl -s ipinfo.io/org)

    # 检查是否为WARP或Cloudflare
    is_warp=false
    if echo "$isp_info" | grep -iq "cloudflare\|warp\|1.1.1.1"; then
        is_warp=true
    fi

    # 判断使用IPv6还是IPv4
    use_ipv6=false
    if [ "$is_warp" = true ] || [ -z "$ipv4_address" ]; then
        use_ipv6=true
    fi

    echo "IPv4: $ipv4_address"
    echo "IPv6: $ipv6_address"
    echo "ISP: $isp_info"
    echo "Is WARP: $is_warp"
    echo "Use IPv6: $use_ipv6"
}

# 检测VPS地理位置
detect_region() {
    local country
    country=$(curl -s ipinfo.io/country)
    case $country in
        "TW") echo "1" ;;          # 台湾
        "HK") echo "2" ;;          # 香港
        "JP") echo "3" ;;          # 日本
        "US" | "CA") echo "4" ;;   # 北美
        "BR" | "AR" | "CL") echo "5" ;;  # 南美
        "GB" | "DE" | "FR" | "NL" | "SE" | "NO" | "FI" | "DK" | "IT" | "ES" | "CH" | "AT" | "BE" | "IE" | "PT" | "GR" | "PL" | "CZ" | "HU" | "RO" | "BG" | "HR" | "SI" | "SK" | "LT" | "LV" | "EE") echo "6" ;;  # 欧洲
        "AU" | "NZ") echo "7" ;;   # 大洋洲
        "KR") echo "8" ;;          # 韩国
        "SG" | "MY" | "TH" | "ID" | "PH" | "VN") echo "9" ;;  # 东南亚
        "IN") echo "10" ;;         # 印度
        "ZA" | "NG" | "EG" | "KE" | "MA" | "TN" | "GH" | "CI" | "SN" | "UG" | "ET" | "MZ" | "ZM" | "ZW" | "BW" | "MW" | "NA" | "RW" | "SD" | "DJ" | "CM" | "AO") echo "11" ;;  # 非洲
        *) echo "0" ;;             # 跨国平台
    esac
}

# 统计使用次数
sum_run_times() {
    local COUNT=$(wget --no-check-certificate -qO- --tries=2 --timeout=2 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fnodeloc%2Fnodeloc_vps_test%2Fblob%2Fmain%2FNlbench.sh" 2>&1 | grep -m1 -oE "[0-9]+[ ]+/[ ]+[0-9]+")
    if [[ -n "$COUNT" ]]; then
        daily_count=$(cut -d " " -f1 <<< "$COUNT")
        total_count=$(cut -d " " -f3 <<< "$COUNT")
    else
        echo "Failed to fetch usage counts."
        daily_count=0
        total_count=0
    fi
}

# 执行单个脚本并输出结果到文件
run_script() {
    local script_number=$1
    local output_file=$2
    local temp_file=$(mktemp)
    # 调用ip_address_and_isp函数获取IP地址和ISP信息
    ip_address_and_isp
    case $script_number in
        # YABS
        1)
            echo -e "运行${YELLOW}YABS...${NC}"
            curl -sL yabs.sh | bash -s -- -i -5 | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i 's/\.\.\./\.\.\.\n/g' "$temp_file"
            sed -i '/\.\.\./d' "$temp_file"
            sed -i '/^\s*$/d'   "$temp_file"
            cp "$temp_file" "${output_file}_yabs" 
            ;;
        # IP质量
        2)
            echo -e "运行${YELLOW}IP质量测试...${NC}"
            echo y | bash <(curl -Ls IP.Check.Place) | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -r 's/(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏)/\n/g' "$temp_file"
            sed -i -r '/正在检测/d' "$temp_file"
            sed -i -n '/########################################################################/,${s/^.*\(########################################################################\)/\1/;p}' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_ip_quality"
            ;;
        # 流媒体解锁
        3)
            echo -e "运行${YELLOW}流媒体解锁测试...${NC}"
            local region=$(detect_region)
            bash <(curl -L -s media.ispvps.com) <<< "$region" | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -n '/流媒体平台及游戏区域限制测试/,$p' "$temp_file"
            sed -i '1d' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_streaming"
            ;;
        # 响应测试
        4)
            echo -e "运行${YELLOW}响应测试...${NC}"
            bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh) | tee "$temp_file"
            sed -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            cp "$temp_file" "${output_file}_response"
            ;;
        # 多线程测速
        5)
            echo -e "运行${YELLOW}多线程测速...${NC}"
            if [ "$use_ipv6" = true ]; then
            echo "使用IPv6测试选项"
            bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "3" | tee "$temp_file"
            else
            echo "使用IPv4测试选项"
            bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "1" | tee "$temp_file"
            fi
            sed -r -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -r '1,/序号\:/d' "$temp_file"
            sed -i -r 's/(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏)/\n/g' "$temp_file"
            sed -i -r '/测试进行中/d' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_multi_thread"
            ;;
        # 单线程测速
        6)
            echo -e "运行${YELLOW}单线程测速...${NC}"
            if [ "$use_ipv6" = true ]; then
            echo "使用IPv6测试选项"
            bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "17" | tee "$temp_file"
            else
            echo "使用IPv4测试选项"
            bash <(curl -sL https://ghfast.top/https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh) <<< "2" | tee "$temp_file"
            fi
            sed -r -i 's/\x1B\[[0-9;]*[JKmsu]//g' "$temp_file"
            sed -i -r '1,/序号\:/d' "$temp_file"
            sed -i -r 's/(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏)/\n/g' "$temp_file"
            sed -i -r '/测试进行中/d' "$temp_file"
            sed -i '/^$/d' "$temp_file"
            cp "$temp_file" "${output_file}_single_thread"
            ;;
        # 回程路由
        7)
            echo -e "运行${YELLOW}回程路由测试...${NC}"
            if [ "$use_ipv6" = true ]; then
            echo "使用IPv6测试选项"
            wget -N --no-check-certificate https://ghfast.top/https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh <<< "4" | tee "$temp_file"
            else
            echo "使用IPv4测试选项"
            wget -N --no-check-certificate https://ghfast.top/https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh <<< "1" | tee "$temp_file"
            fi
            sed -i -e 's/\x1B\[[0-9;]*[JKmsu]//g' -e '/No:1\/9 Traceroute to/,$!d' -e '/测试项/,+9d' -e '/信息/d' -e '/^\s*$/d' "$temp_file"
            cp "$temp_file" "${output_file}_route"
            ;;
    esac
    rm "$temp_file"
    echo -e "${GREEN}测试完成。${NC}"
}

# 生成最终的 Markdown 输出
generate_markdown_output() {
    local base_output_file=$1
    local temp_output_file="${base_output_file}.md"
    local sections=("YABS" "IP质量" "流媒体" "响应" "多线程测速" "单线程测速" "回程路由")
    local file_suffixes=("yabs" "ip_quality" "streaming" "response" "multi_thread" "single_thread" "route")
    local empty_tabs=("去程路由" "Ping.pe" "哪吒 ICMP" "其他")

    # 修改这里，添加 UTF-8 编码设置
    echo "[tabs]" | iconv -f UTF-8 -t UTF-8//IGNORE > "$temp_output_file"

    # 输出有内容的标签
    for i in "${!sections[@]}"; do
        section="${sections[$i]}"
        suffix="${file_suffixes[$i]}"
        if [ -f "${base_output_file}_${suffix}" ]; then
            echo "[tab=\"$section\"]" | iconv -f UTF-8 -t UTF-8//IGNORE >> "$temp_output_file"
            echo "\`\`\`" >> "$temp_output_file"
            cat "${base_output_file}_${suffix}" | iconv -f UTF-8 -t UTF-8//IGNORE >> "$temp_output_file"
            echo "\`\`\`" >> "$temp_output_file"
            echo "[/tab]" >> "$temp_output_file"
            rm "${base_output_file}_${suffix}"
        fi
    done

    # 添加保留的空白标签
    #for tab in "${empty_tabs[@]}"; do
    #    echo "[tab=\"$tab\"]" >> "$temp_output_file"
    #    echo "[/tab]" >> "$temp_output_file"
    #done

    echo "[/tabs]" >> "$temp_output_file"

    # 上传文件 获取回调
    local plain_uploaded_file=$(cat "${temp_output_file}" | curl -s -X POST --data-binary @- "${CLOUD_SERVICE_BASE}")
    local plain_uploaded_file_path=$(echo "$plain_uploaded_file" | grep -oP "(?<=${CLOUD_SERVICE_BASE}).*") 
    local plain_uploaded_file_filename=$(basename "${plain_uploaded_file_path}")

    if [ -n "$plain_uploaded_file" ]; then
        local base_url=$(echo "${CLOUD_SERVICE_BASE}" | sed 's:/*$::')
        local remote_url="${base_url}/result${plain_uploaded_file_path}"
        echo -e "${remote_url}\r\nPlain ${plain_uploaded_file}" > "${plain_uploaded_file_filename}.url"
        echo "测试结果已上传，您可以在以下链接查看："
        echo "${remote_url}"
        echo "Plain ${plain_uploaded_file}"
        echo "结果链接已保存到 ${plain_uploaded_file_filename}.url"
    else
        echo "上传失败. 结果已保存在本地文件 ${temp_output_file}"
    fi


    rm "$temp_output_file"
    read -p "按回车键继续..."  < /dev/tty
    clear
}

# 执行全部脚本
run_all_scripts() {
    local base_output_file="NLvps_results_$(date +%Y%m%d_%H%M%S)"
    echo "开始执行全部测试脚本..."
    for i in {1..10}; do
        run_script $i "$base_output_file"
    done
    generate_markdown_output "$base_output_file"
    clear
}

run_selected_scripts() {
    clear
    local base_output_file="NLvps_results_$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}Nodeloc VPS 自动测试脚本 $VERSION${NC}"
    echo "1. Yabs"
    echo "2. IP质量"
    echo "3. 流媒体解锁"
    echo "4. 响应测试"
    echo "5. 多线程测试"
    echo "6. 单线程测试"
    echo "7. 回程路由"
    echo "0. 返回"

    while true; do
        read -p "请输入要执行的脚本编号（用英文逗号分隔，例如：1,2,3):" script_numbers < /dev/tty
        if [[ "$script_numbers" =~ ^(0|10|[1-7])(,(0|10|[1-7]))*$ ]]; then
            break
        else
            echo -e "${RED}无效输入，请输入0-7之间的数字，用英文逗号分隔。${NC}"
        fi
    done

    if [[ "$script_numbers" == "0" ]]; then
        clear
        show_welcome
        return  # 确保退出函数，不再继续执行
    fi

    # 分割用户输入为数组
    IFS=',' read -ra selected_scripts <<< "$script_numbers"

    echo "开始执行选定的测试脚本..."
    for number in "${selected_scripts[@]}"; do
        clear
        run_script "$number" "$base_output_file"
    done

    # 所有脚本执行完毕后生成 Markdown 输出
    generate_markdown_output "$base_output_file"
}


# 主菜单
main_menu() {
    echo -e "${GREEN}测试项目：${NC}Yabs，IP质量，流媒体解锁，响应测试，多线程测试，单线程测试，回程路由。"
    echo -e "${YELLOW}1. 执行所有测试脚本${NC}"
    echo -e "${YELLOW}2. 选择特定测试脚本${NC}"
    echo -e "${YELLOW}0. 退出${NC}"
    
    # 提示输入并读取，从终端读取输入
    read -p "请选择操作 [0-2]: " choice < /dev/tty

    # 确保输入非空
    if [[ -z "$choice" ]]; then
        echo -e "${RED}输入为空，请重新输入。${NC}"
        sleep 2s
        clear
        main_menu
        return
    fi

    # 检查输入是否合法
    case $choice in
        1)
            run_all_scripts
            ;;
        2)
            run_selected_scripts
            ;;
        0)
            echo -e "${RED}感谢使用NodeLoc聚合测试脚本，已退出脚本，期待你的下次使用！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入。${NC}"
            sleep 2s
            clear
            main_menu
            ;;
    esac
}



# 输出欢迎信息
show_welcome() {
    echo ""
    echo -e "${RED}---------------------------------By'Jensfrank---------------------------------${NC}"
    echo ""
    echo -e "${GREEN}Nodeloc聚合测试脚本 $CURRENT_VERSION ${NC}"
    echo -e "${GREEN}GitHub地址: https://github.com/nodeloc/nodeloc_vps_test${NC}"
    echo -e "${GREEN}Nodeloc社区: https://www.nodeloc.com/${NC}"
    echo ""
    echo -e "${colors[0]}  _   _  ___  ____  _____ _     ___   ____   __     ______  ____  ${NC}"
    echo -e "${colors[1]} | \ | |/ _ \|  _ \| ____| |   / _ \ / ___|  \ \   / /  _ \/ ___| ${NC}"
    echo -e "${colors[2]} |  \| | | | | | | |  _| | |  | | | | |       \ \ / /| |_) \___ \ ${NC}"
    echo -e "${colors[3]} | |\  | |_| | |_| | |___| |__| |_| | |___     \ V / |  __/ ___) |${NC}"
    echo -e "${colors[4]} |_| \_|\___/|____/|_____|_____\___/ \____|     \_/  |_|   |____/ ${NC}"
    echo ""
    echo "支持Ubuntu/Debian"
    echo ""
    echo -e "今日运行次数: ${RED}$daily_count${NC} 次，累计运行次数: ${RED}$total_count${NC} 次"
    echo ""
    echo -e "${RED}---------------------------------By'Jensfrank---------------------------------${NC}"
    echo ""
}

# 主函数
main() {

    # 更新脚本
    update_scripts
    
    # 检查是不是root用户
    check_root
    
    # 检查并安装依赖
    install_dependencies
    
    # 调用函数获取统计数据
    sum_run_times

    # 主循环
    while true; do
        show_welcome
        main_menu
    done
}

# 运行主函数
main
