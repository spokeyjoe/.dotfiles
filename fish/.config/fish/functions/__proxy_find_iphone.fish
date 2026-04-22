function __proxy_find_iphone --description 'Scan local /16 for iPhone proxy on port 6154'
    set -l port 6154

    if not command -q ip
        echo "❌ 'ip' command required (Linux/WSL only)" >&2
        return 1
    end

    if set -q _proxy_last_iphone_ip; and test -n "$_proxy_last_iphone_ip"
        echo "🔍 Trying cached IP $_proxy_last_iphone_ip..." >&2
        if nc -z -w1 $_proxy_last_iphone_ip $port 2>/dev/null
            echo "✅ Cached IP reachable" >&2
            echo $_proxy_last_iphone_ip
            return 0
        end
        echo "⚠️  Cached IP unreachable, rescanning..." >&2
    end

    set -l local_ip (ip route get 1.1.1.1 2>/dev/null | string match -rg 'src (\S+)' | head -1)
    if test -z "$local_ip"
        echo "❌ Could not determine local IP" >&2
        return 1
    end
    set -l parts (string split '.' $local_ip)
    set -l a $parts[1]
    set -l b $parts[2]
    set -l own $parts[3]

    echo "🔎 Scanning $a.$b.0.0/16 for port $port (own /24 first, early-exit)..." >&2
    set -l t_start (date +%s)

    set -l hit (awk -v a=$a -v b=$b -v own=$own -v me=$local_ip 'BEGIN {
            for (d=1; d<=254; d++) { ip=a"."b"."own"."d; if (ip!=me) print ip }
            for (c=0; c<=255; c++) if (c!=own) for (d=1; d<=254; d++) print a"."b"."c"."d
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
