#!/bin/bash

while true; do
    # Get %idle from the last line of mpstat output and subtract from 100
    IDLE=$(mpstat 1 1 | tail -n 1 | awk '{print $NF}')
    UTIL=$(echo "100 - $IDLE" | bc)
    TIMESTAMP=$(date -Is)

    # Use snapctl to write to the 'stats-db' plug view
	snapctl set --view :stats-db data.utilization="$UTIL%" data.last-updated="$TIMESTAMP"
    
    echo "Pushed to ConfDB: $UTIL% at $TIMESTAMP"
    
    sleep 5
done
