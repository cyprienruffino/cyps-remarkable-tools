# Installs an AppLoad application directory on the tablet and restarts xochitl.
#   rm-deploy [--no-restart] <app directory>
# The directory name is used as the application's directory on the tablet.
# RM_HOST picks the ssh host (default: remarkable).

host="${RM_HOST:-remarkable}"
restart=1
if [ "${1:-}" = "--no-restart" ]; then
    restart=0
    shift
fi
if [ $# -ne 1 ] || [ ! -d "$1" ]; then
    echo "Usage: rm-deploy [--no-restart] <app directory>" >&2
    exit 1
fi

app="$(basename "$(realpath "$1")")"
root="/home/root/xovi/exthome/appload"

# Unpack next to the old copy and swap them, since a running backend's
# binary can't be overwritten in place
tar -C "$1" -c . | ssh "$host" "set -e
    rm -rf '$root/$app.new' '$root/$app.old'
    mkdir -p '$root/$app.new'
    tar -x -C '$root/$app.new'
    if [ -d '$root/$app' ]; then mv '$root/$app' '$root/$app.old'; fi
    mv '$root/$app.new' '$root/$app'
    rm -rf '$root/$app.old'"
echo "Installed $app on $host"

if [ "$restart" = 1 ]; then
    ssh "$host" systemctl restart xochitl
    echo "Restarted xochitl"
fi
