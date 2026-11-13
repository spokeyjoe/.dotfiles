function __proxy_find_iphone --description 'Locate iPhone proxy on port 6154 (explicit IP > pinned > cached > scan)'
    # Usage: __proxy_find_iphone [IP]
    #
    # Resolution order:
    #   1. IP passed as argument
    #   2. $proxy_iphone_ip        (pinned:  set -U proxy_iphone_ip 172.22.3.45)
    #   3. $_proxy_last_iphone_ip  (cache of last successful hit)
    #   4. Scan local /16 (skipped under WSL2 NAT, where it is the virtual vNIC net)
    #   5. Scan $proxy_scan_subnets (e.g. set -U proxy_scan_subnets 172.22.0.0/16 10.1.2.0/24)
    #
    # Only /16 and /24 CIDRs are supported for scanning.
    set -l port 6154

    if not command -q ip; or not command -q nc
        echo "❌ 'ip' and 'nc' commands required (Linux/WSL only)" >&2
        return 1
    end

    # --- 1-3: direct candidates ---
    set -l labels "argument" "pinned (\$proxy_iphone_ip)" "cached"
    set -l cands "$argv[1]" "$proxy_iphone_ip" "$_proxy_last_iphone_ip"
    for i in 1 2 3
        set -l ip $cands[$i]
        test -n "$ip"; or continue
        if not string match -qr '^\d{1,3}(\.\d{1,3}){3}$' -- $ip
            echo "⚠️  Ignoring invalid IP '$ip' ($labels[$i])" >&2
            continue
        end
        echo "🔍 Trying $labels[$i] IP $ip..." >&2
        if nc -z -w1 $ip $port 2>/dev/null
            echo "✅ $ip reachable" >&2
            set -U _proxy_last_iphone_ip $ip
            echo $ip
            return 0
        end
        echo "⚠️  $ip:$port unreachable" >&2
        # An explicitly passed IP that fails is a hard error; don't silently scan.
        if test $i -eq 1
            return 1
        end
    end

    # --- Build scan target list: "a.b.c" = /24, "a.b" = /16 ---
    set -l targets
    set -l local_ip (ip route get 1.1.1.1 2>/dev/null | string match -rg 'src (\S+)' | head -1)

    set -l wsl_nat 0
    if command -q wslinfo
        test (wslinfo --networking-mode 2>/dev/null) = nat; and set wsl_nat 1
    else if string match -qi '*microsoft*' (uname -r)
        # Older WSL without wslinfo: default is NAT mode
        set wsl_nat 1
    end

    if test $wsl_nat -eq 1
        echo "ℹ️  WSL2 NAT mode detected: skipping local subnet ($local_ip is the WSL vNIC)." >&2
        echo "   Tip: set networkingMode=mirrored under [wsl2] in %UserProfile%\\.wslconfig" >&2
    else if test -n "$local_ip"
        set -l p (string split '.' $local_ip)
        # own /24 first, then the rest of the /16
        set -a targets "$p[1].$p[2].$p[3]" "$p[1].$p[2]"
    end

    for cidr in $proxy_scan_subnets
        set -l m (string match -rg '^(\d+)\.(\d+)\.(\d+)\.\d+/(16|24)$' -- $cidr)
        if test (count $m) -ne 4
            echo "⚠️  Ignoring unsupported subnet '$cidr' (use a.b.0.0/16 or a.b.c.0/24)" >&2
            continue
        end
        if test $m[4] = 24
            set -a targets "$m[1].$m[2].$m[3]"
        else
            set -a targets "$m[1].$m[2]"
        end
    end

    if test (count $targets) -eq 0
        echo "❌ Nothing to scan. Pass an IP (proxy <ip>), or set:" >&2
        echo "     set -U proxy_iphone_ip <ip>" >&2
        echo "     set -U proxy_scan_subnets 172.22.0.0/16" >&2
        return 1
    end

    echo "🔎 Scanning for port $port in: "(string join ', ' $targets)" (early-exit)..." >&2
    set -l t_start (date +%s)

    # awk expands targets in order, de-duplicating and skipping our own IP.
    set -l hit (printf '%s\n' $targets | awk -v me="$local_ip" '
        function emit(ip) { if (ip != me && !(ip in seen)) { seen[ip] = 1; print ip } }
        {
            n = split($0, o, ".")
            if (n == 3) { for (d = 1; d <= 254; d++) emit($0"."d) }
            else        { for (c = 0; c <= 255; c++) for (d = 1; d <= 254; d++) emit($0"."c"."d) }
        }' | xargs -P 1024 -I{} sh -c "nc -z -w1 {} $port >/dev/null 2>&1 && echo {}" 2>/dev/null | head -1)

    set -l elapsed (math (date +%s) - $t_start)

    if test -z "$hit"
        echo "❌ No proxy found on port $port after "$elapsed"s" >&2
        return 1
    end

    echo "✅ Found proxy at $hit (in "$elapsed"s)" >&2
    set -U _proxy_last_iphone_ip $hit
    echo $hit
    return 0
end
