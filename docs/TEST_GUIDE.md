# 🧪 Eco-Stream GreenOps Test Guide

## 🚗 Step-by-Step Manual Test

### 1. 관제탑 설정 (Control Tower)
새로운 터미널 창(Terminal 1)을 열고 아래 명령어를 입력하여 시스템 상태를 실시간으로 모니터링합니다.
```bash
watch -n 1 "kubectl get pods -l app=eco-worker; echo '---'; tail -n 5 /var/log/greenops.log"
```

### 2. GreenOps Controller 실행 (Engine Start)
다른 터미널 창(Terminal 2)에서 `greenops-controller.sh`가 실행 중인지 확인하고, 없으면 실행합니다.
```bash
# 실행 확인
pgrep -f greenops-controller.sh

# 실행 (백그라운드)
nohup ./greenops-controller.sh > /dev/null 2>&1 &
```

### 3. 부하 발생 (Traffic Storm)
Terminal 2에서 `stress_test.sh`를 실행하여 50개의 비디오 업로드 요청을 보냅니다.
```bash
chmod +x stress_test.sh
./stress_test.sh
```

### 4. 관전 포인트 (What to Watch)
Terminal 1 화면을 주시하세요!

1.  **Waiting (Scale-Out)**: `eco-worker` 파드가 `Pending` 상태로 등장합니다. (노드가 잠겨있기 때문)
2.  **Wake-Up**: `greenops.log`에 `[POWER-ON]` 로그가 뜨면서 노드가 풀립니다 (`Uncordoned`).
3.  **Running**: 파드들이 `Running` 상태로 바뀌고 작업을 시작합니다.
4.  **Cool-Down**: 작업이 다 끝나면 파드가 사라집니다 (`Terminating`).
5.  **Sleep**: 파드가 모두 사라지면 `greenops.log`에 `[POWER-OFF]` 로그가 뜨고 노드가 잠깁니다 (`Cordoned`).

### 5. 로그 확인 (Detailed Logs)
더 자세한 로그를 보고 싶다면:
```bash
cat /var/log/greenops.log
kubectl logs -l app=eco-worker --tail=20
```
