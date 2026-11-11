# Follows xochitl's logs on the tablet, where AppLoad apps log, optionally filtered.
#   rm-logs [pattern]
# RM_HOST picks the ssh host (default: remarkable).

host="${RM_HOST:-remarkable}"
if [ $# -gt 0 ]; then
    ssh "$host" "journalctl -u xochitl -f -n 100 | grep -i -e '$1'"
else
    ssh "$host" journalctl -u xochitl -f -n 100
fi
