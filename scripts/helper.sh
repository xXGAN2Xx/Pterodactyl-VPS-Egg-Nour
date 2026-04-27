#!/bin/sh

# Execute PRoot environment
 
    $HOME/usr/local/bin/proot \
    --rootfs="${HOME}" \
    -0 -w "/root" \
    -b /dev -b /sys -b /proc \
    --kill-on-exit \
    /bin/sh "/run.sh"
