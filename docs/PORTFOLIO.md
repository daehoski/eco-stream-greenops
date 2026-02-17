# 📂 Portfolio: Eco-Kube (GreenOps Platform)

## 💡 프로젝트 선정 배경
> "데이터센터의 전력 소모량은 전 세계 전력의 1% 이상을 차지하며, 그 중 30%는 아무 일도 하지 않는 '좀비 서버'에서 낭비됩니다."

이 문제를 해결하기 위해, **클라우드의 오토스케일링 기술을 베어메탈(물리 서버) 영역까지 확장**하여, 실제 전력 비용을 절감하는 **GreenOps 플랫폼**을 구축했습니다.

---

## 🛠️ 핵심 구현 내용

### 1. Kafka 기반 비동기 버퍼링 (The Dam)
- **문제**: 트래픽 폭주 시 서버가 다운되거나, 모든 물리 서버를 항상 켜놔야 함.
- **해결**: Kafka를 '댐(Dam)'처럼 활용. 요청을 받아두고, 처리 가능한 속도에 맞춰 소비(Consume).
- **효과**: 시스템 안정성 확보 및 예측 가능한 리소스 스케줄링 가능.

### 2. KEDA를 이용한 정밀 스케일링 (The Trigger)
- **코드 (ScaledObject)**:
  ```yaml
  triggers:
  - type: kafka
    metadata:
      topic: video-processing
      lagThreshold: "1" # 메시지 1개당 파드 1개 생성 (즉시 반응)
  ```
- **설명**: CPU 사용량이 아닌, '처리해야 할 작업량(Lag)'을 기준으로 스케일링하여 리소스 낭비 최소화.

### 3. 물리 노드 자동 제어 (The GreenOps Engine)
- **알고리즘**:
  1.  **Wake-Up**: 파드가 `Pending` 상태(갈 곳 없음)가 되면 즉시 `Uncordon` + `WOL` 패킷 전송.
  2.  **Shutdown**: 노드에 할당된 유저 파드가 0개가 되면 `Cordon` + `Shutdown` 명령 전송.
- **코드 (Controller Logic)**:
  ```bash
  # Pending 파드 감지 시
  if [[ "$PENDING" -gt 0 && "$CORDONED" == "true" ]]; then
      ./wake_node.sh  # Send Magic Packet
      kubectl uncordon $NODE
  fi
  
  # 빈 노드 감지 시
  if [[ "$PODS" -eq 0 ]]; then
      kubectl cordon $NODE
      ./sleep_node.sh # SSH Shutdown
  fi
  ```

---

## 성과 및 검증 (Impact)

### 테스트 결과 (Stress Test)
- **시나리오**: 50개의 고화질 영상 업로드 요청 발생.
- **반응 속도**:
  - Kafka Lag 감지 후 파드 생성까지: **< 2초**
  - Pending 파드 감지 후 노드 부팅 신호까지: **< 1초**
- **전력 절감 효과**:
  - 기존: 24시간 × 300W = 7.2kWh 대기 전력 소모.
  - **Eco-Kube**: 트래픽 없을 시 0W. (필요할 때만 가동)

---

## 결론 (Conclusion)
단순한 쿠버네티스 운영을 넘어, **인프라 비용(Cost)**과 **환경(Environment)**을 동시에 고려하는 차세대 인프라 엔지니어링 역량을 증명했습니다.
