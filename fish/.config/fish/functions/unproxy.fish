function unproxy --description 'Disable terminal proxy'
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    set -e no_proxy

    set -e HTTP_PROXY
    set -e HTTPS_PROXY
    set -e ALL_PROXY
    set -e NO_PROXY

    set -e proxy_host
    set -e proxy_http_port
    set -e proxy_socks_port

    echo "🚫 Proxy Disabled"
end
