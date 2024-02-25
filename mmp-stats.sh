#!/usr/bin/env bash

#######################
# MAIN script body
#######################

. "$(dirname "$BASH_SOURCE")/h-manifest.conf"
logPart=$(tail -n 100 "$CUSTOM_LOG_BASENAME.log" | sed -n '/Total hashrate (GPU)/h;//!H;$!d;x;//p')
stats_raw=$(echo "$logPart" | grep "Total hashrate (GPU)")

# Calculate miner log freshness
maxDelay=120
time_now=$(date +%s)
datetime_rep=$(echo "$stats_raw" | awk '{print $1" "$2}' | awk -F\[ '{print $2}' | awk -F] '{print $1}')
time_rep=$(date -d "$datetime_rep" +%s)
diffTime=$((time_now - time_rep))

if [ "$diffTime" -lt "$maxDelay" ]; then
    total_hashrate=$(echo "$stats_raw" | awk '{print $7}')
    if [[ $stats_raw == *"mh/s"* ]]; then
        total_hashrate=$(echo "scale=2; $total_hashrate * 1000" | bc)
    elif [[ $stats_raw == *"gh/s"* ]]; then
        total_hashrate=$(echo "scale=2; $total_hashrate * 1000000" | bc)
    fi

    # GPU Status
    gpu_stats=$(<"$GPU_STATS_JSON")
    readarray -t gpu_stats < <(jq --slurp -r -c '.[] | .busids, .brand, .temp, .fan | join(" ")' "$GPU_STATS_JSON" 2>/dev/null)
    busids=(${gpu_stats[0]})
    brands=(${gpu_stats[1]})
    temps=(${gpu_stats[2]})
    fans=(${gpu_stats[3]})
    gpu_count=${#busids[@]}
    ac=$(tac "$CUSTOM_LOG_BASENAME.log" | grep "Mined block" | head -n 1 | awk '{print substr($5,2);}')
    [[ ! -z "$ac" ]] || ac=0
    rj=$(grep -c "rejected" "$CUSTOM_LOG_BASENAME.log")
    hash_arr=()
    busid_arr=()
    fan_arr=()
    temp_arr=()
    lines=()

    if [ "$(gpu-detect NVIDIA)" -gt 0 ]; then
        brand_gpu_count=$(gpu-detect NVIDIA)
        BRAND_MINER="nvidia"
    elif [ "$(gpu-detect AMD)" -gt 0 ]; then
        brand_gpu_count=$(gpu-detect AMD)
        BRAND_MINER="amd"
    fi

    for ((i = 0; i < gpu_count; i++)); do
        [[ "${brands[i]}" != $BRAND_MINER ]] && continue
        [[ "${busids[i]}" =~ ^([A-Fa-f0-9]+): ]]
        busid_arr+=($((16#${BASH_REMATCH[1]})))
        temp_arr+=(${temps[i]})
        fan_arr+=(${fans[i]})
    done

    logPart=$(echo "$logPart" | sed -n '/Total hashrate (GPU)/,/Total hashrate (CPU)/{/Total hashrate (GPU)/!{/Total hashrate (CPU)/!p}}')
    while read -r string; do
        [[ ! $(echo "$string" | grep 'h/s') ]] && continue
        hashrate=$(echo "$string" | awk '{print $(NF-1)}')
        if [[ $string == *"gh/s"* ]]; then
            hashrate=$(echo "scale=2; $hashrate * 1000" | bc)
        fi
        hash_arr+=($hashrate)
    done <<<"$logPart"

    hash_json=$(printf '%s\n' "${hash_arr[@]}" | jq -cs '.')
    bus_numbers=$(printf '%s\n' "${busid_arr[@]}" | jq -cs '.')
    fan_json=$(printf '%s\n' "${fan_arr[@]}" | jq -cs '.')
    temp_json=$(printf '%s\n' "${temp_arr[@]}" | jq -cs '.')
    uptime=$((date +%s - $(stat -c %Y "$CUSTOM_CONFIG_FILENAME")))

    # Compile stats/khs
    stats=$(jq -nc \
        --argjson index_arr "$busid_arr" \
        --argjson busid_arr "$busid_arr" \
        --argjson hash_arr "[$hash_json]" \
        --argjson air_arr "[$ac, 0, 0]" \
        --arg units "hs" \
        --arg miner_name "your-miner-name" \
        --arg miner_version "1.0" \
        '{ index: $index_arr, busid: $busid_arr, hash: $hash_arr, air: $air_arr, units: $units, miner_name: $miner_name, miner_version: $miner_version }')
    khs=$total_hashrate
else
    khs=0
    stats="null"
fi

echo Debug info:
echo Log file : "$CUSTOM_LOG_BASENAME.log"
echo Time since last log entry : $diffTime
echo Raw stats : "$stats_raw"
echo KHS : $khs
echo AC \ RJ: $ac \ $rj
echo Output : "$stats"

[[ -z $khs ]] && khs=0
[[ -z $stats ]] && stats="null"
