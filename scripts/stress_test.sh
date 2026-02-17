#!/bin/bash

# Configuration
URL="http://localhost:30080/upload"
FILE="test-video.mp4"
COUNT=300

# Ensure dummy file exists
if [ ! -f "$FILE" ]; then
    echo "Creating dummy video file..."
    dd if=/dev/zero of="$FILE" bs=1M count=10 status=none
fi

echo "🚀 Starting Stress Test: Uploading $COUNT videos to Eco-Stream..."
echo "Target: $URL"
echo "---------------------------------------------------"

for i in $(seq 1 $COUNT); do
    response=$(curl -s -o /dev/null -w "%{http_code}" -F "file=@$FILE" "$URL")
    if [ "$response" -eq 200 ]; then
        echo "[$i/$COUNT] ✅ Upload Success"
    else
        echo "[$i/$COUNT] ❌ Upload Failed (HTTP $response)"
    fi
    # Slight delay to not overwhelm curl locally, but fast enough to build lag
    sleep 0.2
done

echo "---------------------------------------------------"
echo "🎉 Stress Test Completed!"
echo "Now watch the magic:"
echo "1. Watch KEDA Scaling: kubectl get hpa,scaledobject -w"
echo "2. Watch Pods Creation: kubectl get pods -l app=eco-worker -w"
echo "3. Watch GreenOps Logs: tail -f /var/log/greenops.log"
