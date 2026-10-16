#!/usr/bin/env bash

# External monitor brightness over DDC/CI. Usage: ext-brightness.sh up|down
# The I2C bus comes from $DDC_BUS, else the first display `ddcutil detect` reports
# (looked up once per boot and cached, since detection takes ~1s).
STEP=10
# Use shared memory (RAM disk) for instantaneous state tracking
CACHE_FILE="/dev/shm/ddc_brightness_cache"
BUS_FILE="/dev/shm/ddc_brightness_bus"

BUS=${DDC_BUS:-}
if [ -z "$BUS" ] && [ -f "$BUS_FILE" ]; then
    BUS=$(cat "$BUS_FILE")
fi
if [ -z "$BUS" ]; then
    BUS=$(ddcutil detect --brief 2>/dev/null | awk '/^Display/{ok=1} /^Invalid/{ok=0} ok && /I2C bus/{sub(/.*i2c-/, ""); print; exit}')
    [ -n "$BUS" ] || exit 1
    echo "$BUS" > "$BUS_FILE"
fi

# Initialize cache from the monitor ONLY if the file doesn't exist yet
if [ ! -f "$CACHE_FILE" ]; then
    CURRENT=$(ddcutil --bus $BUS getvcp 10 | sed -n 's/.*current value = *\([0-9]*\).*/\1/p')
    # If the hardware read fails entirely, default to a safe median value
    if [ -z "$CURRENT" ]; then
        CURRENT=50
    fi
    echo "$CURRENT" > "$CACHE_FILE"
else
    CURRENT=$(cat "$CACHE_FILE")
fi

# Calculate the new target value instantly in memory
if [ "$1" == "up" ]; then
    NEW=$((CURRENT + STEP))
    [ $NEW -gt 100 ] && NEW=100
elif [ "$1" == "down" ]; then
    NEW=$((CURRENT - STEP))
    [ $NEW -lt 0 ] && NEW=0
else
    exit 1
fi

# Instantly update the cache file so consecutive keypresses don't wait
echo "$NEW" > "$CACHE_FILE"

# Fire the absolute update to the hardware without waiting for a read cycle
ddcutil --bus $BUS setvcp 10 $NEW
