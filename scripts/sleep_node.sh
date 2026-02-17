#!/bin/bash
# [GreenOps Simulation]
# 실제 전원 OFF 대신 로그를 기록
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] 🔴 [POWER-OFF] 대기열 해소 확인. Worker 2 절전 모드 진입." >> /var/log/greenops.log