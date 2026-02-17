#!/bin/bash
# [GreenOps Simulation]
# 실제 전원 ON 대신 로그를 기록
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] 🟢 [POWER-ON] 트래픽 급증 감지! Worker 2 (GPU Node) 부팅 신호 전송 완료." >> /var/log/greenops.log