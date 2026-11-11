# Simulates touches and pen strokes on the tablet, in screen pixels.
#   rm-input tap X Y
#   rm-input swipe X1 Y1 X2 Y2 [milliseconds]
#   rm-input pen X1,Y1 X2,Y2 ...
# Copies the device-side tool to the tablet when it changed.
# RM_HOST picks the ssh host (default: remarkable).

host="${RM_HOST:-remarkable}"
remote=/home/root/.local/bin/rm-input
binary="@rmInputDevice@/bin/rm-input"

checksum=$(md5sum "$binary" | cut -d' ' -f1)
if ! ssh "$host" "echo '$checksum  $remote' | md5sum -c -s 2>/dev/null"; then
    ssh "$host" "mkdir -p $(dirname "$remote")"
    scp -q "$binary" "$host:$remote.new"
    ssh "$host" "chmod +x $remote.new && mv $remote.new $remote"
fi

ssh "$host" "$remote" "$@"
