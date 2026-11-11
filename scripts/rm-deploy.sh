# Installs an AppLoad application directory on the tablet.
#   rm-deploy [--restart] <app directory>
# The directory name is used as the application's directory on the tablet.
# RM_HOST picks the ssh host (default: remarkable).
#
# xochitl doesn't need restarting: AppLoad loads an app's files each time it
# opens, and its Reload button picks up new apps. Restarting xochitl while an
# AppLoad app is open can crash it, so --restart is only for xovi extensions.

host="${RM_HOST:-remarkable}"
restart=0
if [ "${1:-}" = "--restart" ]; then
    restart=1
    shift
fi
if [ $# -ne 1 ] || [ ! -d "$1" ]; then
    echo "Usage: rm-deploy [--restart] <app directory>" >&2
    exit 1
fi

app="$(basename "$(realpath "$1")")"
root="/home/root/xovi/exthome/appload"

# Unpack next to the old copy and swap them, since a running backend's
# binary can't be overwritten in place
status=$(tar -C "$1" -c . | ssh "$host" "set -e
    rm -rf '$root/$app.new' '$root/$app.old'
    mkdir -p '$root/$app.new'
    tar -x -C '$root/$app.new'
    if [ -d '$root/$app' ]; then
        mv '$root/$app' '$root/$app.old'
        echo updated
    else
        echo new
    fi
    mv '$root/$app.new' '$root/$app'
    rm -rf '$root/$app.old'
    if ps | grep -v grep | grep -q '$root/$app/backend/entry'; then
        echo running
    fi")
echo "Installed $app on $host"

if [ "$restart" = 1 ]; then
    ssh "$host" systemctl restart xochitl
    echo "Restarted xochitl, give it 30s before taking screenshots"
elif echo "$status" | grep -q running; then
    echo "$app is open on the tablet: close and reopen it to use the new version"
elif echo "$status" | grep -q new; then
    echo "Tap Reload in AppLoad's menu to see it"
fi
