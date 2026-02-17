# Eco-Kube GreenOps Implementation Walkthrough

## 📝 1. 작업 요약 (Summary of Work)
이번 세션에서는 불필요한 전력 소모를 막기 위해 **"빈 노드 만들기(Consolidation)"**와 **"자동 전원 제어(Auto ON/OFF)"** 기능을 구현했습니다.

### 🛠️ 생성 및 수정된 파일 (Changes)
| 구분 | 파일명 | 설명 |
| :--- | :--- | :--- |
| **New** | **`descheduler.yaml`** | **[역할: 청소부]** 흩어져 있는 파드를 정리하여 한 곳으로 모읍니다. (`RemoveDuplicates`, `RemovePodsViolatingNodeAffinity` 정책 사용) |
| **New** | **`greenops-controller.sh`** | **[역할: 관리자]** 노드의 파드 개수를 감시합니다. <br> - **파드 0개**: 노드 폐쇄(Cordon) -> 절전 모드(`sleep_node.sh`) <br> - **대기 파드 발생**: 노드 개방(Uncordon) -> 부팅(`wake_node.sh`) |
| **Mod** | **`sleep_node.sh`** | 실제 종료 대신 로그를 남기도록 연동 확인. |
| **Mod** | **`wake_node.sh`** | 실제 부팅 대신 로그를 남기도록 연동 확인. |

---

## 🧪 2. 테스트 시나리오 (Verification)
시스템이 다음 순서대로 작동하는지 검증합니다.

### **Step 1: Shutdown (Idle 상태)**
- **상황**: 트래픽 없음, `k8s-worker2`에 파드가 0개.
- **예상 동작**:
    1. Controller가 빈 노드 감지.
    2. `kubectl cordon k8s-worker2` 실행 (스케줄링 금지).
    3. `sleep_node.sh` 실행 -> **Power Off 로그 기록**.

### **Step 2: Wake-Up (Traffic 급증)**
- **상황**: 트래픽 폭주로 새 파드가 생성되려 하지만, 공간 부족 또는 특정 노드 필요.
- **예상 동작**:
    1. 파드가 갈 곳이 없어 `Pending` 상태 발생.
    2. Controller가 `Pending` 감지.
    3. `wake_node.sh` 실행 -> **Power On 로그 기록**.
    4. `kubectl uncordon k8s-worker2` 실행 (스케줄링 허용).
    5. 파드가 `k8s-worker2`에 할당됨.

## ✅ 3. 검증 결과 (Results)

### 3.1 Wake-Up 테스트 (20:09:28)
- **Action**: `greenops-test-pod` 생성 (NodeSelector: k8s-worker2).
- **Log 확인**:
  ```text
  [2026-02-17 20:09:28] 🚀 Pending pods detected (2). Waking up k8s-worker2...
  [2026-02-17 20:09:28] 🟢 [POWER-ON] 트래픽 급증 감지! Worker 2 (GPU Node) 부팅 신호 전송 완료.
  [2026-02-17 20:09:28] 🔓 Node k8s-worker2 uncordoned.
  ```
- **결과**: 노드가 Uncordon 되고 파드가 정상적으로 Running 상태가 됨.

### 3.2 Shutdown 테스트 (20:10:09)
- **Action**: `kubectl delete pod greenops-test-pod` 실행.
- **Log 확인**:
  ```text
  [2026-02-17 20:10:09] ⚠️  Node k8s-worker2 is idle (0 user pods). Initiating shutdown sequence...
  [2026-02-17 20:10:09] Locked node (Cordon).
  [2026-02-17 20:10:09] 🔴 [POWER-OFF] 대기열 해소 확인. Worker 2 절전 모드 진입.
  ```
- **결과**: 파드가 사라지자마자 노드가 Cordon 되고 절전 모드로 진입함.

## 🚀 4. 최종 시나리오 검증: Eco-Stream (20:30:00)

### 4.1 시나리오 흐름
1. **Upload**: 사용자가 `eco-web`을 통해 비디오 업로드.
2. **Buffer**: Kafka `video-processing` 토픽에 메시지 적재.
3. **Trigger**: KEDA가 메시지를 감지하고 `eco-worker` 파드 스케일링 (0 -> 1).
4. **Wake-Up**: `Pending` 상태 파드 감지 -> `greenops-controller.sh`가 `k8s-worker2` 부팅 (Uncordon).
5. **Process**: `eco-worker` 파드가 실행되어 비디오 변환 수행.
6. **Sleep**: 작업 완료 후 메시지 소진 -> KEDA 스케일인 (1 -> 0) -> `greenops-controller.sh`가 `k8s-worker2` 종료 (Cordon).

### 4.2 검증 로그
**Step 1. Upload & Wake-Up**
```text
[2026-02-17 20:25:39] 🚀 Pending pods detected (1). Waking up k8s-worker2...
[2026-02-17 20:25:39] 🟢 [POWER-ON] 트래픽 급증 감지! Worker 2 (GPU Node) 부팅 신호 전송 완료.
```

**Step 2. Processing (Pod Logs)**
```text
♻️ [RECEIVED] Processing video: test-video.mp4
🎬 [FFmpeg] Transcoding test-video.mp4 to H.265 (HEVC)...
✅ [DONE] Finished test-video.mp4 in 5.01s. Waiting for next...
```

**Step 3. Shutdown (After Cooldown)**
```text
[2026-02-17 20:30:00] ⚠️  Node k8s-worker2 is idle (0 user pods). Initiating shutdown sequence...
[2026-02-17 20:30:00] Locked node (Cordon).
[2026-02-17 20:30:00] 🔴 [POWER-OFF] 대기열 해소 확인. Worker 2 절전 모드 진입.
```

### 🎊 결론
**"트래픽이 들어오면 켜지고, 일이 끝나면 꺼지는"** 완전 자동화된 친환경 쿠버네티스 플랫폼 구축을 완료했습니다.

### 5.1 Stress Test (Extended)
**Scenario**: 300 Video Uploads (To force extended scale-out)
- **Load**: 300 requests sent via `stress_test.sh`.
- **Scaling**: KEDA scaled `eco-worker` to **10 replicas (Max)**.
- **Processing**: All 10 pods actively processed videos for ~5 minutes.
- **Scale-In**:
    - Queue empty -> Cooldown (30s) -> Scale to 0.
    - Node `k8s-worker2` shutdown triggered immediately.

### 5.2 Troubleshooting (Key Learnings)
- **Issue**: Pods stuck at 3 replicas instead of 10.
    - **Cause**: Kafka Topic `partitions` was set to 3.
    - **Fix**: Increased partitions to 10.
- **Issue**: Consumers stuck/idle despite high lag.
    - **Cause**: Stale metadata in consumers after topic update.
    - **Fix**: Restarted deployments (`kubectl rollout restart`) to refresh metadata.
- **Outcome**: System successfully handled 300 requests with full 10-pod parallelism.
