# Copies xochitl's own QML and JavaScript from the tablet, to see how its UI is
# built, e.g. to reuse its components in AppLoad apps.
#   rm-dump-qml <output directory>
# It installs a small AppLoad app, "QML dump", that does the copying when
# opened, waits for it to finish, then removes it.
# RM_HOST picks the ssh host (default: remarkable).
#
# xochitl's QML is reMarkable's code: keep the dump for reference, don't
# publish it.

host="${RM_HOST:-remarkable}"
if [ $# -ne 1 ]; then
    echo "Usage: rm-dump-qml <output directory>" >&2
    exit 1
fi
output="$1"
app=/home/root/xovi/exthome/appload/xochitl-qml-dump
remote=/home/root/.cache/xochitl-qml

ssh "$host" "rm -rf $app $remote && mkdir -p $app $remote"
tar -C "@qmlDump@" -c . | ssh "$host" "tar -x -C $app"
echo "Installed the QML dump app: open AppLoad, tap Reload, then open \"QML dump\""

until ssh "$host" "[ -f $remote/done ]"; do
    sleep 2
done
echo "Dumped $(ssh "$host" "cat $remote/done")"

mkdir -p "$output"
ssh "$host" "tar -C $remote -c ." | tar -x -C "$output"
rm -f "$output/started" "$output/done"
# Restore the directory structure flattened on the tablet
for file in "$output"/*__*; do
    [ -e "$file" ] || continue
    target="$output/$(basename "$file" | sed 's|__|/|g')"
    mkdir -p "$(dirname "$target")"
    mv "$file" "$target"
done
ssh "$host" "rm -rf $app $remote"
echo "Saved to $output; close the QML dump app, and tap Reload in AppLoad to remove it"
