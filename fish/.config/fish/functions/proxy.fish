function proxy --description 'Enable terminal proxy'
    echo "🌐 Select Proxy Profile:"
    echo "   [1] 🏢 Company (iPhone Hotspot -> 172.22.102.137)"
    echo "   [2] 🏠 Home (Mac Surge -> 127.0.0.1)"
    echo "   [0] ❌ Cancel"

    read -l -P "👉 Enter choice [1]: " choice
    set choice (string trim "$choice")

    # Default: 1
    if test -z "$choice"
        set choice 1
    end

    switch $choice
        case 1
            # --- Company (iPhone) ---
            set -gx proxy_host "172.22.102.137"
            set -gx proxy_http_port "6154"
            set -gx proxy_socks_port "6153"
            set -gx proxy_type "Company (iPhone)"
        case 2
            # --- Home (Mac Surge) ---
            set -gx proxy_host "127.0.0.1"
            set -gx proxy_http_port "6152"
            set -gx proxy_socks_port "6153"
            set -gx proxy_type "Home (Surge)"
        case 0
            echo "Operation cancelled."
            return 0
        case '*'
            echo "Invalid choice."
            return 1
    end

    set -gx http_proxy "http://$proxy_host:$proxy_http_port"
    set -gx https_proxy "http://$proxy_host:$proxy_http_port"
    set -gx HTTP_PROXY "http://$proxy_host:$proxy_http_port"
    set -gx HTTPS_PROXY "http://$proxy_host:$proxy_http_port"

    set -gx all_proxy "socks5://$proxy_host:$proxy_socks_port"
    set -gx ALL_PROXY "socks5://$proxy_host:$proxy_socks_port"

    set -l no_proxy_list "localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,172.22.0.0/16"

    set -gx no_proxy $no_proxy_list
    set -gx NO_PROXY $no_proxy_list

    echo "✅ Proxy Enabled [$proxy_type]:"
    echo "   HTTP/HTTPS -> $proxy_host:$proxy_http_port"
    echo "   SOCKS5     -> $proxy_host:$proxy_socks_port"
end
