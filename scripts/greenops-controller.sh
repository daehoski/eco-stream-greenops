#!/bin/bash

# Configuration
NODE_NAME="k8s-worker2"
LOG_FILE="/var/log/greenops.log"
KUBE_CMD="kubectl"

# Resolve script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check node status (cordoned or not)
is_node_cordoned() {
    $KUBE_CMD get node $NODE_NAME -o jsonpath='{.spec.unschedulable}' 2>/dev/null
}

# Function to check if node is empty (no user pods)
is_node_empty() {
    local pod_count=$($KUBE_CMD get pods --field-selector=spec.nodeName=$NODE_NAME -A --no-headers | grep -v kube-system | grep -v strimzi | grep -v calico | wc -l)
    [ "$pod_count" -eq 0 ]
}

# Function to check Kafka lag
get_kafka_lag() {
    local lag=$($KUBE_CMD get kafka my-cluster -n kafka -o=jsonpath='{.status.topics[?(@.name=="video-processing")].partitions[0].consumerLag}')
    echo "${lag:-0}"
}

log "Starting GreenOps Controller for node: $NODE_NAME"

# Main loop
while true; do
    # Check KEDA scaling and Kafka lag
    lag=$(get_kafka_lag)
    
    # Check if any eco-worker pods are pending (meaning node is needed)
    pending_pods=$($KUBE_CMD get pods -l app=eco-worker -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' | wc -w)
    
    cordoned=$(is_node_cordoned)

    # 1. Wake Up Logic: Pending Pods OR (Lag > 0 AND Node Empty & Cordoned)
    if [[ "$pending_pods" -gt 0 && "$cordoned" == "true" ]]; then
        log "Pending pods detected ($pending_pods). Waking up $NODE_NAME..."
        "$SCRIPT_DIR/wake_node.sh"
        $KUBE_CMD uncordon $NODE_NAME
        
    elif [[ "$lag" -gt 0 && "$(is_node_empty)" == "true" && "$cordoned" == "true" ]]; then
        log "Kafka lag detected ($lag) and node is empty but cordoned. Waking up $NODE_NAME..."
        "$SCRIPT_DIR/wake_node.sh"
        $KUBE_CMD uncordon $NODE_NAME

    # 2. Scale-In/Shutdown Logic: No Lag AND No Pending Pods AND Node Empty
    elif [[ "$lag" -eq 0 && "$pending_pods" -eq 0 ]]; then
        if [[ "$(is_node_empty)" == "true" && "$cordoned" != "true" ]]; then
            log "Node $NODE_NAME is idle (0 user pods). Initiating shutdown sequence..."
            $KUBE_CMD cordon $NODE_NAME
            "$SCRIPT_DIR/sleep_node.sh" # Execute shutdown command
            
        elif [[ "$(is_node_empty)" != "true" && "$cordoned" == "true" ]]; then
             # Node is cordoned but not empty (maybe manual intervention?), uncordon it to be safe
             log "Node $NODE_NAME is cordoned but not empty. Uncordoning."
             $KUBE_CMD uncordon $NODE_NAME
        fi
    fi

    sleep 5
done
