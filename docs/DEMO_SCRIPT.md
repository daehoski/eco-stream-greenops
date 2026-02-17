# Eco-Kube Demo Script

## Scene 1: Intro (0:00 ~ 0:30)
- **화면**: `README.md` 아키텍처 다이어그램.
- **멘트**: "안녕하세요. 베어메탈 환경을 위한 GreenOps 플랫폼, Eco-Kube입니다. 이 프로젝트는 트래픽에 따라 물리 서버의 전원을 실제로 끄고 켜서, 유휴 전력을 0으로 만듭니다."

## Scene 2: Setup & Idle 
- **화면**: 터미널 (왼쪽: `watch kubectl get pods`, 오른쪽: `greenops-controller` 로그).
- **액션**: 
    1. 현재 `eco-worker` 파드가 0개임을 보여줌.
    2. 로그에 아무런 활동이 없거나 `[POWER-OFF]` 상태임을 강조.
- **멘트**: "현재 처리할 작업이 없어 Worker 2 노드는 꺼져있는 상태입니다. 전력 소모는 0와트입니다."

## Scene 3: Traffic Spike! (Highlight)
- **화면**: 공격 터미널 추가 (`./stress_test.sh` 실행 준비).
- **액션**: 
    1. **`./stress_test.sh` 실행!**
    2. 화면 전환 -> 모니터링 터미널.
    3. **KEDA 동작 확인**: 파드가 순식간에 `Pending`으로 쌓이는 것 보여줌.
    4. **Controller 동작 확인**: 로그에 `[POWER-ON]`이 뜨고, 파드들이 `Running`으로 바뀌는 순간 포착.
- **멘트**: "갑자기 50개의 영상 업로드가 발생했습니다. KEDA가 이를 감지하고 파드를 생성하지만 공간이 부족합니다. 이때, GreenOps 엔진이 노드를 깨웁니다!"

## Scene 4: Processing & Scale-In
- **화면**: 파드들이 `Running` 상태에서 하나둘씩 `Terminating` 되는 모습.
- **멘트**: "깨어난 노드에서 영상 변환을 빠르게 처리하고 있습니다. 작업이 끝나면 KEDA가 파드를 줄입니다."

## Scene 5: Shutdown (Conclusion)
- **화면**: 마지막 파드가 사라지고, 로그에 `[POWER-OFF]`가 찍히는 순간.
- **멘트**: "모든 작업이 끝나 노드가 비워졌습니다. 시스템은 다시 절전 모드로 진입합니다. 감사합니다."
