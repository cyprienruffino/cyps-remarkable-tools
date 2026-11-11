# Installs a xovi extension (.so) on the tablet and restarts xochitl to load it.
#   rm-deploy-extension <extension.so>
# xovi loads extensions when xochitl starts, and a broken one crashes it on
# every start until the tablet reboots, so this:
#   - refuses to run while an AppLoad app is open (restarting xochitl then can crash it)
#   - waits for xochitl to settle, then checks it didn't crash and still runs with xovi
#   - removes the extension and restarts xochitl again if it did crash
# RM_HOST picks the ssh host (default: remarkable).

host="${RM_HOST:-remarkable}"
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
    echo "Usage: rm-deploy-extension <extension.so>" >&2
    exit 1
fi
name="$(basename "$1")"
remote="/home/root/xovi/extensions.d/$name"

ssh "$host" 'set -e
    pid=$(pidof xochitl) || { echo "xochitl is not running" >&2; exit 1; }
    if ! tr "\0" "\n" < /proc/$pid/environ | grep -q "^LD_PRELOAD=.*xovi"; then
        echo "xochitl is running without xovi, start it with /home/root/xovi/start" >&2
        exit 1
    fi
    if ps | grep -v grep | grep -q "/exthome/appload/.*/backend/entry"; then
        echo "An AppLoad app is open, close it first" >&2
        exit 1
    fi'

scp -q "$1" "$host:$remote.new"
ssh "$host" "mv $remote.new $remote && systemctl restart xochitl"
echo "Installed $name, restarted xochitl, waiting for it to settle"
sleep 35

status=$(ssh "$host" '
    pid=$(pidof xochitl) || { echo down; exit; }
    tr "\0" "\n" < /proc/$pid/environ | grep -q "^LD_PRELOAD=.*xovi" || { echo stock; exit; }
    echo "up $(systemctl show xochitl -p NRestarts --value)"')
# A manual restart resets xochitl's restart counter, so any crash since shows up
case "$status" in
"up 0")
    echo "xochitl is up with $name"
    ssh "$host" "journalctl -u xochitl --since -60s --no-pager -o cat | grep -i '\[${name%.so}\]' | tail -n 5"
    ;;
*)
    echo "xochitl crashed with $name (${status:-unreachable}), removing it" >&2
    # Repeated crashes reboot the tablet, so keep trying while it comes back:
    # left in place, the extension would crash xochitl again once xovi starts
    for _ in $(seq 24); do
        if ssh -o ConnectTimeout=5 "$host" "rm -f $remote" 2>/dev/null; then
            echo "Removed $name" >&2
            ssh "$host" '
                if tr "\0" "\n" < /proc/$(pidof xochitl)/environ | grep -q "^LD_PRELOAD=.*xovi"; then
                    systemctl restart xochitl
                    echo "Restarted xochitl" >&2
                else
                    echo "The tablet rebooted: start xovi again with /home/root/xovi/start" >&2
                fi'
            exit 1
        fi
        sleep 5
    done
    echo "Couldn't reach the tablet to remove $remote: remove it before starting xovi again" >&2
    exit 1
    ;;
esac
