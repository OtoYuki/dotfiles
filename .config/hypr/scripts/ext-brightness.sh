#!/usr/bin/env bash

BUS=16
STEP=10
# Use shared memory (RAM disk) for instantaneous state tracking
CACHE_FILE="/dev/shm/asus_brightness_cache"

# Initialize cache from the monitor ONLY if the file doesn't exist yet
if [ ! -f "$CACHE_FILE" ]; then
    CURRENT=$(ddcutil --bus $BUS getvcp 10 | grep -oP 'current value =\s+\K[0-9]+')
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
