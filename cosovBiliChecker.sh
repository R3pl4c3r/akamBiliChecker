#!/bin/bash

proxy=""

domain_name="upos-sz-mirrorcosov.bilivideo.com"

trap 'onCtrlC' INT
function onCtrlC () {
	kill 0
}

ip_list="$*"
while getopts ":f:" opt
do
    case $opt in
        f)
        ip_file="$OPTARG"
        ;;
        ?)
        ;;
    esac
done

[[ -f $ip_file ]] && ip_list=$(cat $ip_file)
# echo "#1#"$ip_file $ip_list
[[ -n $ip_list ]] && ip_arr=($ip_list) && num=${#ip_arr[@]}
[[ -z $ip_list ]] && ip_arr="" && num=1

[[ -n $proxy ]] && url=$(ykdl -J --proxy $proxy https://www.bilibili.com/video/BV1ss411h7t4 |  jq -r '.streams."BD-80".src[0]')
# [[ -z $proxy ]] && url=$(ykdl -J https://www.bilibili.com/video/BV1ss411h7t4 |  jq -r '.streams."BD-80".src[0]')
[[ -z $proxy ]] && url=$(curl -Gs 'http://api.bilibili.com/x/player/playurl' \
--data-urlencode 'bvid=BV1ss411h7t4' \
--data-urlencode 'cid=13097922' \
--data-urlencode 'qn=80' \
--data-urlencode 'fnval=0' \
--data-urlencode 'fnver=0' \
--data-urlencode 'fourk=1' 2>&1 | jq -r '.data.durl[0].url')
[[ -z $url ]] && echo "ERROR: PLS check your ydkl, exit ..." && exit 0
domain=$(echo $url | awk -F[/:] '{print $4}')
[[ ! $url =~ $domain_name ]] && echo -e "ERROR: There is no '$domain_name' found in the url extracted by YKDL, pls check your PROXY settings or YKDL installation, the URL is \n>>> $url" && exit 0

echo -e "Checking '$domain_name' extracted by YKDL with: \n>>> $url\n"

port="80"
[[ "$url" =~ ^https.* ]] && port="443"


f_list=""

for i in $(seq 0 $[num-1])
do
if [[ -n $ip_arr ]]; then
    ip=${ip_arr[i]}
    resolve="--resolve $domain:$port:$ip"
else
    resolve=""
fi

d_speed=""
http_c=""

out=$(timeout -k 3 15 curl --referer "https://www.bilibili.com/video/BV1ss411h7t4" -o /dev/null -s -w \
"time_connect: %{time_connect}\n\
time_starttransfer: %{time_starttransfer}\n\
time_nslookup:%{time_namelookup}\n\
time_pretransfer: %{time_pretransfer}\n\
time_redirect: %{time_redirect}\n\
time_total: %{time_total}\n\
speed_download: %{speed_download}\n\
size_download: %{size_download}\n\
ssl_verify_result: %{ssl_verify_result}\n\
remote_ip: %{remote_ip}\n\
http_code: %{http_code}\n\n" -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36' $resolve $url)

d_speed=$(echo $out | sed -r 's/.*speed_download: ([0-9]+).*/\1/')
http_c=$(echo $out | sed -r 's/.*http_code: ([0-9]+).*/\1/')
curl_ip=$(echo $out | sed -r 's/.*remote_ip: ([0-9\.]+).*/\1/')
[[ -z $d_speed ]] && d_speed="0"
[[ -z $http_c ]] && http_c="err"
[[ -z $ip ]] && ip=$curl_ip
f_list=$f_list"\n"$d_speed" "$http_c" "$ip
echo "Checking procedure ( $[i+1] in $num ) ... $domain >>> $ip"
echo -e "$out\n"
done

echo -e "\nTest & Sort result: "
echo -en $f_list | sort -t " " -k 1 -n
# | tee $out_file
