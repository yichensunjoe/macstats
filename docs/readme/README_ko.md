<div align="center">

[简体中文](../../README.md) · [English](README_en.md) · [繁體中文](README_zh-TW.md) · [日本語](README_ja.md) · **한국어** · [Deutsch](README_de.md) · [Español](README_es.md) · [Français](README_fr.md) · [Русский](README_ru.md) · [Português (Brasil)](README_pt-BR.md)

# MacStats Panel

### 활동 모니터를 바탕화면에 고정해 두세요.

**CPU, 메모리, GPU, 에너지, 디스크, 네트워크를 한눈에. 모든 수치는 활동 모니터와 맞춰져 있습니다.**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#설치)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#동작-방식)
[![tests](https://img.shields.io/badge/tests-176%20passing-3fb950?style=flat-square)](#명령)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#동작-방식)

[설치](#설치) · [표시 항목](#표시-항목) · [두 가지 형태](#두-가지-형태) · [정확도](#활동-모니터와-얼마나-일치하는가) · [FAQ](#faq) · [알려진-제한](#알려진-제한)

**[MacStats.zip 다운로드](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)** · `/Applications`로 드래그한 뒤, 첫 실행은 시스템 설정 → '확인 없이 열기'로 허용

</div>

---

## 설치

[**MacStats.zip 다운로드**](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip) (약 2.5 MB, macOS 15+ / Apple 실리콘)

1. 압축을 풀고 `MacStats.app`을 `/Applications`로 드래그
2. 첫 실행은 차단됩니다(**공증되지 않음**). 경고에서 '완료'를 누른 뒤 시스템 설정 → 개인정보 보호 및 보안 → '확인 없이 열기'로 허용하거나, 터미널에서 격리 속성을 제거하세요. 이유와 두 방법은 [설치 안내](../install.md) 참고
3. 데스크톱에 패널이 나타납니다. 시스템 위젯은 데스크톱을 오른쪽 클릭 → '위젯 편집' → '系统监视' 검색 (갤러리에 표시되는 위젯 이름)

```bash
# 선택 사항: 다운로드 격리 속성을 한 번 지우면 이후에는 더블 클릭으로 열립니다
xattr -dr com.apple.quarantine /Applications/MacStats.app

# 또는 Homebrew
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats      # Homebrew 5+는 서드파티 tap을 명시적으로 신뢰해야 합니다
brew install --cask macstats
```

다운로드 검증: `shasum -a 256 -c MacStats.zip.sha256` (체크섬은 Release에 첨부).

**설치가 안 될 때**

1. **Gatekeeper가 차단**: 위 방법 중 하나로 허용하세요(시스템 설정의 '확인 없이 열기' 또는 격리 속성 제거). 앱이 손상되었다는 메시지가 뜨면 대개 다운로드가 불완전한 경우이니 먼저 sha256을 검증하고, 실패하면 다시 받으세요. 검증을 통과했는데도 같은 메시지가 나오면 격리 속성을 지우는 방법으로 엽니다.
2. **아키텍처 불일치**: 배포 패키지는 Apple 실리콘(arm64) 전용이며 Intel Mac에서는 실행되지 않고 Rosetta 빌드도 없습니다. `uname -m`이 `arm64`를 출력해야 합니다.
3. **macOS 버전이 낮음**: macOS 15(Sequoia) 이상이 필요합니다. `sw_vers -productVersion`으로 확인하세요.
4. **시스템 위젯이 보이지 않음**: 앱이 `/Applications`에 있는지(다운로드 폴더나 `~/Applications`가 아닌지), 한 번 이상 실행했는지 확인한 뒤 `killall chronod NotificationCenter`를 실행하고 앱을 다시 여세요. 한 Mac에는 앱 하나만 등록되어야 합니다.
5. **업그레이드 후에도 위젯이 이전 버전**: 새 `MacStats.app`을 `/Applications`에 덮어써도 확장 기능 등록은 자동으로 갱신되지 않아 이전 빌드 기록으로 로드될 수 있습니다. 먼저 앱을 종료했다가 다시 여세요. 그래도 안 되면 확장 기능을 강제로 다시 등록합니다(`lsregister` + `pluginkit`, 명령은 [설치 안내](../install.md)). 버전은 새것인데 데스크톱 모습이 그대로라면 '위젯 편집'에서 한 번 제거한 뒤 다시 추가하세요.
6. **Homebrew가 untrusted tap을 보고**: Homebrew 5부터 서드파티 tap은 명시적 신뢰가 필요합니다. `brew trust yichensunjoe/macstats` 후 `brew install --cask macstats`를 실행하고, `brew untrust yichensunjoe/macstats`로 철회할 수 있습니다. Homebrew는 격리 속성을 지우지 않으므로 첫 실행에는 위의 허용 절차가 필요합니다.

<p align="center">
  <img src="../live-window.png" alt="MacStats 데스크톱 패널: CPU, 메모리, GPU, 에너지, 디스크, 네트워크와 메모리 상위 3개 프로세스" width="460" />
</p>

활동 모니터는 이미 모든 정보를 보여 줍니다. 문제는 그게 '창'이라는 점입니다. 열고, 탭을 고르고, 앞으로 가져와야 하죠. MacStats는 같은 여섯 개 지표를 바탕화면에 늘 떠 있는 어두운 패널로 만들어 1초마다 샘플링하고, 크기에 맞춰 레이아웃을 다시 잡고, 데스크톱 격자에 작은 위젯을 두고 싶은 사람을 위해 WidgetKit 위젯도 함께 제공합니다.

지표를 늘리지는 않습니다. 활동 모니터의 다섯 항목에 GPU 사용률과 통합 메모리 사용량을 더하고, 90초 추세선·코어별 사용률·메모리 구성·메모리 상위 3개 프로세스까지 더한 것이 전부입니다. 시간이 든 부분은 화면이 아니라 **각 숫자를 활동 모니터와 똑같이 만드는 일**이었습니다. 같은 순간에 나란히 놓고 비교하면 메모리는 0.2 GB 이내, 디스크와 네트워크 누적값은 바이트 단위로 일치합니다.

<p align="center">
  <img src="../compact-strip.png" alt="넓은 스트립: CPU·메모리·GPU·에너지·디스크·네트워크를 한 줄로" width="620" />
  <br />
  <img src="../compact-strip-narrow.png" alt="좁은 스트립: 같은 6개 지표가 3 × 2 그리드로 접힘" width="330" />
</p>

**패널을 길게 줄이면 최소 레이아웃이 됩니다.** 카드도 추세선도 없이 여섯 개 지표가 한 줄로 놓여 메뉴 막대 아래 표시등처럼 쓰입니다. 한 줄에 들어가지 않을 만큼 좁아지면 3 × 2 그리드로 접혀 여섯 개가 모두 남습니다. 1초 갱신 기준 CPU는 한 코어의 약 1%, 상주 메모리는 80MB 정도입니다(arm64 + macOS 26 실측). 이 단계의 그리기 비용이 가장 적습니다.새로 설치하면 이 형태가 기본입니다. 오른쪽 클릭 → '표준 패널로 펼치기'로 전체 패널이 되고, 같은 항목으로 다시 접을 수 있습니다.

> [!NOTE]
> 데스크톱 패널은 바로 쓸 수 있습니다. 시스템 위젯 갤러리에 나오는 버전은 유효한 Apple Development 서명과 `/Applications` 설치가 필요합니다. 둘 다 `chronod`의 강제 조건이며 선택 사항이 아닙니다. 자세한 내용은 [시스템 위젯](#시스템-위젯)을 참고하세요.

## 소스에서 빌드

macOS 15 이상과 Xcode 명령줄 도구(Swift 6)가 필요합니다. 서드파티 의존성도, Xcode 프로젝트 파일도 없습니다.

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # 빌드 + 번들 + /Applications 설치 + 위젯 등록
open /Applications/MacStats.app
```

처음 실행하면 메뉴 막대에 `CPU · 메모리` 표시가 생기고 바탕화면에 패널이 나타납니다.

- 메뉴 막대 아이콘 왼쪽 클릭: 패널 표시 / 숨김
- 패널 오른쪽 클릭: 항상 위, 바탕화면에 고정, 클릭 통과, 새로 고침 간격(1 / 2 / 5초), 새 인스턴스
- 빈 곳을 끌어 이동하고 오른쪽 아래 손잡이로 크기를 바꿉니다. 레이아웃은 '최소 / 컴팩트 / 표준 / 상세'로 자동 전환됩니다
- 환경설정은 앱의 `com.macstats.app` 환경설정 도메인에 저장되어 다시 실행해도 위치와 크기가 유지됩니다

## 표시 항목

| 지표 | 패널 표시 | 측정 방식 |
|---|---|---|
| CPU | 큰 전체 값 + 사용자/시스템 + 90초 추세 + 코어별 막대 | `host_processor_info` 차분, 활동 모니터와 같은 소스 |
| 메모리 | 사용/전체, 압력 막대, App / Wired / 압축 구성, 캐시 | `vm_statistics64`, [정확도](#활동-모니터와-얼마나-일치하는가) 참고 |
| 에너지 | CPU 에너지 카운터로 환산한 와트, 배터리 잔량과 충전 상태 | `ri_energy_nj` 차분. 카운터가 없으면 부하 기반 추정치로 대체하고 그 사실을 표시 |
| 디스크 | 읽기/쓰기 속도, 여유 공간 | `IOBlockStorageDriver` 누적 바이트 차분 |
| 네트워크 | 업/다운 속도, 기본 인터페이스 | 64비트 `NET_RT_IFLIST2` 카운터. 속도에서 `lo0` 제외 |
| GPU | 사용률 큰 숫자 + 90초 추세선 + 통합 메모리 사용량 / 코어 수 | `IOAccelerator`의 `PerformanceStatistics`(`Device Utilization %`, `In use system memory`). 활동 모니터 GPU 탭과 같은 소스 |
| 프로세스 | 메모리 상위 3개(큰 위젯은 5개) | `proc_pid_rusage`의 `ri_phys_footprint` |

<p align="center">
  <img src="../widget-medium.png" alt="중간 크기 위젯: 코어별 막대가 있는 CPU와 메모리, 디스크, 네트워크, 에너지, GPU(지원 시) 타일" width="620" />
  <img src="../widget-small.png" alt="작은 크기 위젯: 큰 CPU 숫자와 추세선" width="280" />
</p>

## 24시간 기록과 지속적인 고부하 알림

표준·상세 패널에는 '지난 24시간' 줄이 있습니다. CPU·메모리·GPU 세 개의 곡선과 각각의 24시간 피크입니다. 피크는 숫자만이 아니라, 클릭하면 그 시각과 값에 더해 **당시 CPU 사용률이 가장 높았던 3개 프로세스**(이름, CPU%, 메모리, 각각 한 줄 설명)가 열립니다. 샘플링은 여전히 초당 1회이고, 저장은 분 단위 평균을 JSONL로 `~/Library/Application Support/MacStats/history/`에 기록합니다. 각 분 기록에는 그때 가장 바빴던 3개 프로세스도 함께 담기며, 하루 약 0.4 MB, 기본 30일 보관합니다. 설정 → 지표 모니터링에서 7 / 30 / 90일로 바꾸거나 한 번에 지울 수 있습니다.

솔직한 한계 두 가지: **GPU 피크에는 프로세스가 나오지 않습니다**(현재 샘플링으로는 프로세스별 GPU 사용률을 안정적으로 얻을 수 없음). **이 버전 이전에 기록된 히스토리에는 프로세스 정보가 없습니다** — 클릭하면 '당시 프로세스는 기록되지 않음'이라고 표시하며, 지금의 프로세스 목록으로 대체하지 않습니다.

'지속적인 고부하 알림'은 기본 꺼짐입니다. 켜면 CPU ≥ 90%, 메모리 ≥ 85%, 디스크 ≥ 90%가 **연속 3회 샘플** 동안 유지되어야 알림이 가고, 같은 지표는 10분에 한 번까지만 반복됩니다. 한 번의 스파이크로 방해받지 않습니다. 알림 본문에는 해당 프로세스 이름이 들어갑니다. CPU 이벤트는 CPU 1위, 메모리 이벤트는 메모리 1위(따로 순위)를 쓰고, 디스크 이벤트는 프로세스 귀속이 없어 값만 보고합니다.

## 유휴 백그라운드 프로세스 일괄 정리

메뉴 막대(또는 패널) → '유휴 백그라운드 프로세스 정리…'. **남겨진 고아 프로세스**만 대상으로 합니다. 사용자가 시작했고, 부모가 이미 종료됐고, 제어 터미널이 없고, 자식도 소켓도 없으며, 10분 동안 CPU 활동이 없는 프로세스입니다. 먼저 목록과 종료 전 확보한 메모리 합계(macOS가 실제로 회수하는 양은 아님)를 보여 주고, 확인한 뒤에야 `SIGTERM`을 보냅니다. 3초가 지나도 살아 있으면 그대로 두며 `SIGKILL`로 올리지 않습니다.

항상 제외: 시스템 프로세스(`/System`, `/usr`, `/Library` 등의 경로), App과 그 보조 프로세스(경로에 `.app/` 포함), tty에 연결된 명령, 최전면 App, 부모가 살아 있는 자식 프로세스, TCP/UDP/Unix 소켓을 가진 프로세스, 프로세스 자신의 자식, 그리고 화이트리스트에 있는 이름(메뉴 → '정리 화이트리스트', 실행 파일 이름과 `argv[0]` 둘 다 비교). 체크한 이름은 ✓와 함께 하위 메뉴에 남아 다시 클릭하면 해제되며, '화이트리스트 비우기'로 초기화합니다.

### 모든 프로세스에 쉬운 설명이 붙습니다

확인 창은 각 프로세스에 대해 '무엇인지'와 '끝내면 어떻게 되는지'를 적습니다. 예를 들어 `npm run dev`는 '로컬 개발 서버. 끄면 로컬 페이지가 열리지 않고 핫 리로드도 멈춥니다', `github-mcp-server`는 'AI 어시스턴트에 추가 도구를 제공. 끄면 그 도구 하나가 사라지고 앱을 다시 열 때까지 돌아오지 않습니다'. 알 수 없는 프로세스는 'X라는 이름의 백그라운드 명령, 창도 아이콘도 없음'이라고 솔직히 적고 추측하지 않습니다. 문구는 `ProcessGlossary.swift`에 있으며 `argv[0]` → 실행 파일 이름 → 설치 경로 순으로 맞추는 순수 함수입니다.

바쁜 Mac에서는 '정리할 프로세스가 없습니다'라고 자주 나옵니다. 이는 설계대로이며 고장이 아닙니다. 실제로 걸리는 것은 크래시 뒤 남은 고아 `node` / `python` / 스크립트 프로세스입니다. 좀비(상태 `Z`)는 대상이 아닙니다 — 이미 종료됐고 부모만 회수할 수 있습니다.

읽기 전용 확인(아무것도 종료하지 않음):

```bash
cd src && .build/debug/macstatsDiag --cleanup-dry-run
```

## 설정 창

메뉴 막대 → '설정…'(또는 ⌘,)을 열면 표준 설정 창이 뜨고, 탭은 다섯 개입니다.

| 탭 | 내용 |
|---|---|
| 일반 | 언어(시스템 따르기 / 简体中文 / English), 메뉴 막대 수치, 로그인 시 실행, 시작 시 숨기기, 정리 효과음과 알림, 메모리 압력 경고 |
| 외관 및 패널 | 테마(시스템 / 다크 / 라이트), 색상(선명 / 단색), 데스크톱 위젯 표시, 패널 형태(미니멀 스트립 / 컴팩트 / 표준 / 상세), 항상 위, 클릭 통과 |
| 지표 모니터링 | 새로 고침 간격, 평활 창(1 / 3 / 5초), 상위 프로세스 수(3 / 5 / 8), 기록과 7 / 30 / 90일 보관, 한 번에 지우기, 지속적인 고부하 알림 |
| 백그라운드 정리 | 유휴·메모리 기준, 검색 가능한 프로세스 목록(각 항목에 쉬운 설명), 체크로 보호, 이름 직접 입력, 새로 고침과 비우기 |
| 이 App에 관하여 | 버전, 빌드 아키텍처, 데이터 소스, 일치도 설명, 활동 모니터 열기, 진단 실행 |

오른쪽 클릭 메뉴는 일상 동작만 남깁니다: 표시/숨기기, 펼치기/접기, 위젯 추가, 정리, 화이트리스트, 활동 모니터, 설정, 종료.

## 두 가지 형태

샘플링 계층은 하나, 호스트는 둘:

| | 데스크톱 패널 | 시스템 위젯 (WidgetKit) |
|---|---|---|
| 새로 고침 | 1초마다 다시 그림 | 시스템 예산에 따라 약 60초에 한 번 |
| 위치 | 어디로든 이동, 여러 인스턴스 가능 | 데스크톱 배치 격자 |
| 진입 | 메뉴 막대 아이콘 / `open MacStats.app` | 바탕화면 오른쪽 클릭 → '위젯 편집' → 'MacStats' 검색 |
| 크기 | 자유롭게 조절, 네 단계 레이아웃 | 소 / 중 / 대 / 특대 고정 |
| 전제 | 없음 | 유효한 서명 + `/Applications` 설치 + `_NSExtensionMain` 진입점 |

움직이는 게 보이길 원하면 패널, 다른 위젯과 나란히 두고 싶으면 시스템 위젯을 쓰세요. 둘 다 같은 스냅숏을 읽으므로 두 값이 어긋날 수 없습니다.

## 활동 모니터와 얼마나 일치하는가

방법은 이렇습니다. 활동 모니터와 패널을 같은 화면에 두고, 접근성 API로 활동 모니터의 값을 읽어 같은 순간의 샘플과 항목별로 비교합니다.

| 항목 | 결과 |
|---|---|
| 메모리: 사용 / 캐시 / App / Wired / 압축 | 0.2 GB 이내(활동 모니터 자체가 5초 동안 화면을 캐시) |
| 디스크: 누적 읽기 / 누적 쓰기 | 바이트 단위로 일치 |
| 네트워크: 누적 수신 / 누적 송신 | 바이트 단위로 일치(십진 GB) |
| 프로세스 메모리 | 같은 PID에서 0.0 MB |
| CPU | 안정 부하에서 1~3 퍼센트포인트 차이(샘플링 구간 위상차) |

<p align="center">
  <img src="../monitor-compare.png" alt="위: 활동 모니터의 메모리 탭. 아래: 같은 순간의 MacStats 패널" width="700" />
</p>

여기까지 오면서 세 가지 '당연한' 가정을 고쳤습니다:

- **누적 네트워크 트래픽은 IFMIB 64비트 카운터에서 읽어야 합니다.** `NET_RT_IFLIST2`의 `ifi_ibytes`는 하위 32비트만 채워서, 되돌아간 뒤 이 기기의 `lo0` 122.9 GB가 2.6 GB로 읽혔습니다. 누적값에는 `lo0`을 포함하고(활동 모니터도 포함), 속도 열에서는 제외합니다. 그러지 않으면 루프백 트래픽 때문에 속도가 약 60배로 부풀어 오릅니다.
- **'사용'은 'App + Wired + 압축'이 아닙니다.** 활동 모니터의 사용 메모리는 물리 − (free − speculative) − 파일 캐시이고, 캐시된 파일은 파일 캐시 + 정리 가능 페이지입니다. 직관이 아니라 정의대로 구현해야 합니다.
- **에너지는 '에너지 영향'이 아닙니다.** 그 열은 무차원 상대 점수라 재현할 수 없습니다. 패널은 물리적 와트를 보여 주고 타일에 'CPU 에너지 카운터'라고 적어 점수와 섞지 않습니다.

## 동작 방식

세 계층, 어느 것도 UI에 의존하지 않습니다:

```
MacStatsCore  샘플링과 환산(순수 로직, 단위 테스트 대상)
      ↓
WidgetData    스냅숏 + 90개 링 이력
      ↓
SwiftUI 뷰    패널과 WidgetKit 확장이 공유
```

- **샘플링**: Mach(`host_processor_info`, `host_statistics64`), IOKit(디스크 통계, 전원), `sysctl(NET_RT_IFLIST2)`, `sysctl(vm.swapusage)`, libproc(`proc_listpids` / `proc_pid_rusage`). 공개 API만 사용합니다. sudo도, SIP 변경도, 비공개 프레임워크도 없습니다.
- **속도 지표는 최근 5개 샘플의 이동 평균**으로, 활동 모니터의 기본 5초 구간에 맞추고 깜빡임도 줄입니다.
- **패널은 데스크톱 계층의 `NSPanel`**입니다. 비활성 패널로 모든 Space에 붙고 포커스를 가져가지 않아서, 클릭해도 작업 중인 창이 뒤로 밀리지 않습니다.
- **데이터는 기기 밖으로 나가지 않습니다**: 네트워크 요청, 텔레메트리, 계정이 없고 사용자 파일도 읽지 않습니다. 공개 API로 시스템 카운터를 읽어 위젯 확장용 로컬 JSON 하나를 쓸 뿐입니다.

## 명령

| 목적 | 명령 |
|---|---|
| 빌드 + 번들 + 설치 | `bash scripts/bundle.sh` |
| 단위 테스트 | `cd src && swift test` |
| 샘플러 자체 점검 | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| 원시 카운터 출력 | `cd src && .build/debug/macstatsDiag --raw` |
| JSON 스냅숏 | `cd src && .build/debug/macstatsDiag --json` |
| 패널 오프스크린 렌더 | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| 네 가지 위젯 크기 렌더 | `bash scripts/preview-widget.sh` |

## 프로젝트 구조

```
src/Sources/MacStatsCore/    샘플링, 메모리 환산, 링 이력, 포매팅(UI 없음)
src/Sources/MacStats/        SwiftUI 패널, 메뉴 막대 앱, 컨텍스트 메뉴, 오프스크린 렌더
src/Sources/MacStatsWidget/  WidgetKit 확장: 타임라인 프로바이더 + 네 단계 뷰
src/Sources/MacStatsDiag/    진단 CLI(--json / --raw / --self-check)
src/Tests/                   XCTest, 176개
scripts/bundle.sh            release 빌드, appex 조립, 서명, 설치, 등록
docs/                        정확도 검증, 아키텍처, 요구 사항, 스크린숏
```

## 시스템 위젯

확장은 `MacStats.app/Contents/PlugIns/MacStatsWidget.appex`에 들어 있고 크기별로 레이아웃이 다릅니다. 위젯 갤러리에 나오려면 세 가지가 모두 필요하며, 전부 직접 부딪혀서 알게 된 것들입니다:

1. **확장에는 유효한 서명이 있어야 하고 샌드박스여야 합니다.** `pkd`는 ad-hoc 서명을 거부하고, 실제 인증서를 써도 appex에 `com.apple.security.app-sandbox`가 없으면 `rejecting; … plug-ins must be sandboxed`와 함께 조용히 버려집니다. 무료 개인 팀 인증서(Xcode → Settings → Accounts에서 Apple ID 로그인)로 충분합니다.
2. **앱은 `/Applications`에 있어야 하고, 등록도 하나여야 합니다.** `chronod`는 시스템 응용 프로그램 폴더에서만 호스트를 찾습니다. 프로젝트 폴더나 사용자 Applications 폴더에 두면 `Ignoring restricted or unknown extension`이 기록됩니다. 같은 번들 ID를 두 곳에 등록하면 launchd가 XPC 인스턴스를 두 개 만들고 `chronod`는 실제 프로세스에 닿지 못합니다. `bundle.sh`는 이 전제에 맞춰 설치하고 예전 등록을 정리합니다.
3. **appex 진입점은 `_NSExtensionMain`이어야 합니다.** Xcode의 `LD_ENTRY_POINT` 기본값입니다. SwiftPM 기본 진입점을 쓰면 프로세스는 뜨고 `main [WidgetBundle]`도 출력하지만 호스트 XPC 세션을 맺지 못하고 약 15 ms 뒤에 죽은 것으로 판정되며 크래시 리포트도 남지 않습니다. `src/Package.swift`에서 `linkerSettings`로 고정해 두었습니다.

샌드박스에서는 확장이 호스트 앱의 `UserDefaults`를 읽을 수 없어서 데이터를 JSON 스냅숏으로 주고받습니다. 앱은 Application Support 폴더의 `MacStats/widget-feed.json`을 2초마다 다시 쓰고, 확장 컨테이너가 있으면 그쪽에도 복사합니다. 확장이 새 스냅숏을 찾지 못하면 스스로 한 번 샘플링합니다.

`security find-identity -v -p codesigning`이 `0 valid identities`를 보여 주면 보통 키체인에 Apple의 WWDR G3 중간 인증서가 없는 경우입니다. Xcode에 포함된 `AppleWWDRCA-2030.cer`을 가져오면 됩니다.

확장을 고친 뒤에는 `CFBundleVersion`을 올리세요. `chronod`는 버전별로 descriptor를 캐시하므로 그대로 두면 예전 화면이 계속 보입니다.

## FAQ

<details>
<summary><strong>위젯이 왜 1분에 한 번만 갱신되나요?</strong></summary>

WidgetKit은 렌더 루프가 아니라 '예약된 스냅숏'입니다. 타임라인이 항목 하나를 주면 만료 시점에 다음 항목을 요청합니다. 앱이 15초마다 `reloadAllTimelines()`를 호출해도 `chronod`는 예산으로 조절합니다(로그에 `budgeted-1`). 서드파티 위젯에는 초 단위 갱신이 허용되지 않으며, 시스템 시계 같은 것은 시스템의 특권입니다.

실시간 숫자는 1초마다 갱신되는 데스크톱 패널을 쓰세요.

</details>

<details>
<summary><strong>메모리 상위 목록에 WindowServer가 없는 이유는?</strong></summary>

다른 사용자의 프로세스(예: `_windowserver`)는 읽을 수 없습니다. `proc_pid_rusage`는 EPERM을, `proc_pidinfo`는 0바이트를 돌려줍니다. 활동 모니터는 Apple 엔타이틀먼트가 있어 전부 볼 수 있습니다. 계산 오류가 아니라 권한 경계입니다.

</details>

<details>
<summary><strong>활동 모니터와 여전히 조금 다릅니다.</strong></summary>

활동 모니터는 5초마다 갱신하며 이전 갱신 시점의 스냅숏을 보여 주고, 패널은 1초마다 갱신합니다. 같은 순간에 비교하면 메모리는 최대 0.2 GB, 속도와 CPU는 샘플링 구간 위상차만큼 어긋납니다. 한 주기 기다렸다가 다시 비교하면 일치합니다.

</details>

<details>
<summary><strong>데이터를 어디로 보내나요?</strong></summary>

아니요. 네트워크 요청, 텔레메트리, 계정이 없고 사용자 파일도 읽지 않습니다. 공개 API로 시스템 카운터를 읽고 위젯 확장을 위한 로컬 JSON 하나를 씁니다.

</details>

<details>
<summary><strong>Intel Mac도 지원하나요?</strong></summary>

아니요. 배포 패키지는 Apple 실리콘(arm64) 전용이며, Intel 빌드도 Rosetta 경로도 없습니다. Intel Mac에서는 실행되지 않습니다.

</details>

## 알려진 제한

- **시스템 위젯은 약 60초에 한 번 움직입니다.** WidgetKit의 스케줄 한도이며 앱에서 우회할 수 없습니다.
- **에너지는 물리적 와트**이고 활동 모니터의 '에너지 영향' 점수가 아닙니다. 두 값은 단위가 대응하지 않습니다.
- **프로세스 목록은 현재 사용자만** 포함하고 메모리 순으로 정렬합니다. 패널은 3개, 샘플링 계층은 최대 24개를 유지합니다.
- **이력은 로컬에만, 분 단위까지**: 분마다 집계해 JSONL로 저장하고 7 / 30 / 90일 중 선택해 보관합니다. 클라우드 동기화나 초 단위 재생은 없습니다.
- **알림은 세 항목만**: CPU / 메모리 / 디스크가 3회 연속 임계값을 넘을 때만 알리며 기본은 꺼져 있습니다. 온도, 팬, 단일 프로세스 이상은 감시하지 않습니다.
- **원격 모니터링은 하지 않습니다**: 모든 측정값과 이력은 이 Mac에만 남고 네트워크로 전송되지 않습니다.

## 문서

자세한 기록은 중국어로 작성되어 있습니다.

- [정확도 검증](../monitor-alignment.md): 각 값을 어떻게 활동 모니터에 맞췄는지, 실측값 포함.
- [아키텍처](../architecture.md): 계층, 데이터 흐름, 설계상의 절충.
- [요구 사항](../requirements.md): 범위, 비목표, 인수 기준.

## 라이선스

이 프로젝트는 [MIT 라이선스](../../LICENSE)로 배포됩니다. 저작권 고지와 라이선스 전문을 유지하는 한 상업적 용도를 포함해 자유롭게 사용, 수정, 재배포할 수 있습니다.
