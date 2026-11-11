# Takes a screenshot of the tablet with rm-shot and copies it here.
#   rm-screenshot [output.png]
# Needs the rm-shot xovi extension (with framebuffer-spy and xovi-message-broker).
# RM_HOST picks the ssh host (default: remarkable).

host="${RM_HOST:-remarkable}"
output="${1:-rm-screenshot.png}"
remote=/home/root/.cache/rm-screenshot.png

# rm-shot crashes xochitl when asked for a screenshot while it's still
# starting, so check that it has been up for a while, with xovi loaded
ssh "$host" 'set -e
    pid=$(pidof xochitl) || { echo "xochitl is not running" >&2; exit 1; }
    if ! tr "\0" "\n" < /proc/$pid/environ | grep -q "^LD_PRELOAD=.*xovi"; then
        echo "xochitl is running without xovi, start it with /home/root/xovi/start" >&2
        exit 1
    fi
    if [ ! -p /run/xovi-mb ] || [ ! -p /run/xovi-mb-out ]; then
        echo "xovi-message-broker is not running" >&2
        exit 1
    fi
    started=$(systemctl show xochitl -p ActiveEnterTimestampMonotonic --value)
    uptime=$(cut -d. -f1 /proc/uptime)
    if [ $((uptime - started / 1000000)) -lt 30 ]; then
        echo "xochitl started less than 30s ago, try again in a moment" >&2
        exit 1
    fi
    rm -f '"$remote"'
    echo ">etakeScreenshot:'"$remote"',0" > /run/xovi-mb
    result=$(timeout 5 cat /run/xovi-mb-out)
    if [ "$result" != success ]; then
        echo "rm-shot answered: $result" >&2
        exit 1
    fi
    # The screenshot is written by a thread, after the answer
    for i in 1 2 3 4 5 6 7 8 9 10; do
        [ -s '"$remote"' ] && break
        sleep 0.5
    done
    [ -s '"$remote"' ] || { echo "no screenshot was written" >&2; exit 1; }
    [ "$(pidof xochitl)" = "$pid" ] || { echo "xochitl restarted while taking the screenshot" >&2; exit 1; }'

scp -q "$host:$remote" "$output"
echo "$output"
