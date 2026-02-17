# 베어메탈 서버의 전기를 꺼버리는 쿠버네티스 — Eco-Kube GreenOps 프로젝트

## 들어가며

데이터센터 전력 소모량은 전 세계 전력의 1% 이상을 차지합니다.
그 중 약 30%는 아무 일도 하지 않는 **"좀비 서버"**에서 낭비됩니다.

AWS, GCP 같은 퍼블릭 클라우드는 서버리스(Serverless)로 이 문제를 해결했지만,
**온프레미스(베어메탈) 환경**에서는 여전히 서버가 24시간 전력을 소비하고 있습니다.

> "트래픽이 없는데 왜 서버가 켜져있어야 하지?"

이 단순한 질문에서 출발해, **유휴 상태의 물리 서버를 자동으로 꺼버리는 플랫폼**을 만들었습니다.

---

## 프로젝트 개요: Eco-Kube

| 항목 | 내용 |
|:---|:---|
| **프로젝트명** | Eco-Kube (Eco-Stream GreenOps) |
| **목표** | 유휴 베어메탈 노드의 전력을 0W로 만들기 |
| **핵심 기술** | Kubernetes, Kafka (KRaft), KEDA, Kepler, Prometheus+Grafana |
| **환경** | 3노드 베어메탈 클러스터 (Master + Worker1 + Worker2) |
| **GitHub** | [eco-stream-greenops](https://github.com/daehoski/eco-stream-greenops) |

---

## 아키텍처

전체 시스템은 크게 3개의 레이어로 구성됩니다.

### 1. 요청 버퍼링 계층 (Kafka)
사용자가 영상을 업로드하면, 바로 처리하지 않고 **Kafka 토픽에 메시지로 적재**합니다.
Kafka는 댐(Dam)처럼 요청을 받아두고, Worker가 처리 가능한 속도에 맞춰 소비(Consume)합니다.

이렇게 하면:
- 트래픽 폭주에도 시스템이 죽지 않음
- Worker가 없어도 메시지가 유실되지 않음 (버퍼링)
- Worker가 깨어나면 Kafka에 쌓인 일부터 처리 시작

### 2. 이벤트 기반 스케일링 (KEDA)
기존 Kubernetes HPA는 **CPU 사용률**을 기준으로 스케일링합니다.
하지만 이건 "지금 바쁜가?"만 알 수 있고, **"처리해야 할 일이 얼마나 쌓여있는가?"**는 모릅니다.

KEDA는 **Kafka Consumer Lag**(= 아직 처리 안 된 메시지 수)을 직접 보고 스케일링합니다.

```yaml
triggers:
- type: kafka
  metadata:
    topic: video-processing
    lagThreshold: "1"    # 메시지 1개 = 파드 1개
    consumerGroup: eco-worker-group
```

- Lag 0 -> Pod 0개 (완전 제로)
- Lag 50 -> Pod 10개 (최대)
- Lag 해소 -> 30초 쿨다운 후 다시 0개

### 3. 물리 노드 전원 제어 (GreenOps Controller)
여기가 이 프로젝트의 **핵심 차별점**입니다.

일반적인 쿠버네티스 오토스케일링은 "파드 수"만 조절합니다.
하지만 파드가 0개여도 **노드 자체는 켜져있기 때문에 전력을 소모**합니다.

Eco-Kube는 한 발 더 나아갑니다:

```
[파드 0개 감지] → kubectl cordon (스케줄링 차단) → 물리 서버 Shutdown (SSH)
[새 작업 감지]  → Wake-on-LAN 패킷 전송 → kubectl uncordon → 파드 스케줄링
```

직접 개발한 `greenops-controller.sh`가 이 로직을 수행합니다:
- 10초 간격으로 노드 상태 모니터링
- Pending 파드 감지 시 즉시 노드 기상 (WOL)
- 빈 노드 감지 시 Cordon + Shutdown

---

## 실제 검증: 300건 스트레스 테스트

### 테스트 조건
- 업로드: 300개 영상 파일 (0.2초 간격)
- Worker: 최대 10개 병렬 처리
- Kafka: 10개 파티션

### 결과

| 지표 | 수치 |
|:---|:---|
| 스케일아웃 반응 | Lag 감지 후 < 2초 |
| 최대 파드 수 | 10개 (maxReplicaCount) |
| 전체 처리 시간 | 약 5분 |
| 스케일인 완료 | 큐 비움 → 30초 쿨다운 → 0개 |
| 노드 셧다운 | 파드 0개 후 즉시 Cordon + Shutdown |

### Grafana 모니터링
Prometheus + Grafana + Kepler를 통해 전체 라이프사이클을 시각화했습니다:

- **파드 수 변화**: 0 → 10 → 0 전체 사이클
- **CPU/Memory 사용량**: Worker 노드 부하 추이
- **전력 소비량 (Kepler)**: 노드별 실시간 와트(W) 측정
- **HPA 상태**: Current vs Desired Replicas

---

## 트러블슈팅: Kafka 파티션 문제

프로젝트 진행 중 흥미로운 버그를 만났습니다.

### 증상
10개 Worker Pod가 띄워졌는데, 실제로 일하는 건 3개뿐.
나머지 7개는 "Listening for messages..."만 출력하며 놀고 있었습니다.

### 원인
Kafka 토픽을 처음에 파티션 3개로 만들었다가, 나중에 10개로 늘렸습니다.
그런데 이미 떠있던 Consumer들이 **이전 메타데이터(파티션 3개)**를 기억하고 있어서,
새로 추가된 7개 파티션의 메시지를 가져가지 않았습니다.

### 해결
```bash
kubectl rollout restart deployment eco-web eco-worker
```
Consumer를 재시작하면 Kafka에서 최신 메타데이터를 받아와 10개 파티션 모두에서 소비를 시작합니다.

### 교훈
> Kafka 토픽 구조를 변경한 후에는 반드시 Consumer를 재시작해야 합니다.
> 프로덕션 환경에서는 Rolling Update로 무중단 리프레시가 가능합니다.

---

## 기술 스택 정리

| Category | Technology | 역할 |
|:---|:---|:---|
| **Orchestration** | Kubernetes v1.29 | 컨테이너 오케스트레이션 |
| **Event Bus** | Kafka (KRaft) | 대용량 트래픽 버퍼링 |
| **Auto Scaling** | KEDA | Kafka Lag 기반 Pod 스케일링 |
| **Scheduling** | Descheduler | 빈 노드 생성을 위한 파드 재배치 |
| **Power Mgmt** | Custom Bash | 물리 노드 WOL/Shutdown 제어 |
| **Monitoring** | Prometheus + Grafana | 메트릭 수집 및 시각화 |
| **Power Monitoring** | Kepler (eBPF) | 컨테이너 단위 전력 측정 |
| **Application** | Flask + Python | 비디오 업로드 웹 서비스 |

---

## 마치며

이 프로젝트의 핵심은 단순한 "쿠버네티스 설치기"가 아닙니다.

**"파드 스케일링을 넘어, 물리 인프라의 전원까지 자동화할 수 있는가?"**

라는 질문에 대한 실험이었습니다.

클라우드 네이티브 기술(Kafka, KEDA, Kepler)을 조합하면,
온프레미스 환경에서도 **"쓸 때만 켜고, 안 쓸 때는 꺼버리는"** 진정한 의미의 서버리스를 구현할 수 있습니다.

전체 소스코드는 GitHub에서 확인하실 수 있습니다:
-> [https://github.com/daehoski/eco-stream-greenops](https://github.com/daehoski/eco-stream-greenops)

---

**태그**: #Kubernetes #쿠버네티스 #Kafka #KEDA #GreenOps #베어메탈 #온프레미스 #DevOps #인프라 #Kepler #전력절감 #포트폴리오
