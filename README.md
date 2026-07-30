# onprem-k3s-deploy

온프레미스 서버에 **k3s 클러스터**를 구성하는 Ansible 플레이북. server 1대 + agent N대.
손으로 하던 `curl -sfL https://get.k3s.io | sh -` 과정을 그대로 옮긴 것이다.

```bash
uv sync --group dev                        # 1. ansible 설치 (최초 1회)
cp inventory.ini.example inventory.ini     # 2. 인벤토리 준비
vi inventory.ini                           #    IP / 계정 / 버전 입력
uv run ansible k3s -m ping                 # 3. 연결 확인 ← pong 나와야 함
uv run ansible-playbook site.yml           # 4. 구축

KUBECONFIG=./kubeconfig kubectl get nodes    # 확인
uv run ansible-playbook reset.yml            # 전부 제거
```

| 파일 | 역할 |
|---|---|
| `inventory.ini.example` | 인벤토리 템플릿 (커밋됨) |
| `inventory.ini` | 실제 서버 목록 + 접속정보 + 변수 ← **여기만 고치면 된다** (커밋 안 됨) |
| `site.yml` | 클러스터 구성 (play 6개) |
| `reset.yml` | 전부 제거 (실습/재구성용) |
| `ansible.cfg` | 도구 설정. 이름 고정 |

각 파일 주석에 상세 설명이 있다.
기존 Ansible 학습 정리는 [ansible-test/](ansible-test/) 로 옮겨뒀다.

## 준비

```bash
uv sync --group dev          # ansible 설치 (프로젝트 .venv 격리)
sudo apt install sshpass     # 비번 인증용
```

이후 모든 명령은 `uv run` 을 붙인다.

**리모트 요구사항:** SSH 접속 + Python 3 + sudo. OS 는 Debian/Ubuntu 또는 RHEL 계열
(그 외는 사전 점검에서 막는다). 에이전트 설치는 없다.

**인벤토리는 템플릿만 커밋한다.** `inventory.ini.example` 을 `inventory.ini` 로 복사해서
실제 값을 넣어라 — 복사한 쪽은 gitignore 로 막혀 있어 실수로 커밋되지 않는다.
`ansible.cfg` 가 `./inventory.ini` 를 기본으로 가리키므로 `-i` 플래그는 필요 없다.

버전은 실제 배포 전에 최신으로 갱신해라.

- k3s — https://github.com/k3s-io/k3s/releases
- k9s — https://github.com/derailed/k9s/releases

**`ping` 에서 막히는 건 전부 SSH 문제다.** 플레이북으로 해결되지 않는다.
실행 시 비번을 두 번 물어본다 (SSH, sudo). 같으면 두 번째는 엔터.
멱등하므로 두 번째 실행은 `changed=0` 이어야 정상이다.

## 플레이북 구조

| play | 대상 | 내용 |
|---|---|---|
| 0 | 전 노드 | 사전 점검 (server 1대인지, sudo, OS). 아무것도 안 바꿈 |
| 1 | 전 노드 | 기본 패키지, docker(선택) |
| 2 | server | k3s 설치, API 대기, **join 토큰 읽기** |
| 3 | agent | 토큰으로 클러스터 join |
| 4 | server | helm, k9s |
| 5 | server → 내 PC | kubeconfig 가져오기 (IP 치환) |

핵심은 2번의 `slurp` → 3번의 `hostvars` 로 토큰이 넘어가는 부분이다.
손으로 토큰 복붙하던 과정을 대체한다.

## 주의사항

**업그레이드는 안 된다.** `creates:` 가 skip 시키므로 `k3s_version` 만 올려도 반영되지 않는다.
해당 줄을 임시로 지우고 돌리거나, 운영이라면
[system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) 를 써라.

**`-l` 로 agent 만 지정하면 실패한다.** 토큰을 server 에서 읽어 넘기기 때문이다.
노드 추가 시엔 server 를 함께 포함해라 (이미 설치됐으므로 대부분 skip 된다).

```bash
uv run ansible-playbook site.yml -l k3s_server,node4
```

**docker 는 클러스터와 무관하다.** k3s 는 자체 containerd 를 쓴다. 이미지 빌드용이며
필요 없으면 `install_docker=false`. 그룹 추가는 재로그인 후 적용된다.

**`kubeconfig` 는 커밋하지 마라.** admin 인증서가 들어있다 (gitignore 처리됨).

**sysctl / firewall 은 건드리지 않는다.** k3s 설치 스크립트가 알아서 하고,
OS baseline 은 시스템엔지니어 영역이다. 나중에 튜닝이 필요하면 `/etc/sysctl.conf` 를
덮지 말고 `/etc/sysctl.d/90-k3s.conf` 처럼 drop-in 으로 추가해라.

## 미지원

수작업 과정을 옮긴 최소 구성이다. 아래가 필요해지면 `k3s-io/k3s-ansible` 이나
`xanmanning.k3s` role 로 갈아타는 게 맞다 — 직접 쓰는 건 손해다.

HA(server 3대 + etcd), kube-vip, MetalLB, airgap 설치, registry mirror.
클러스터 내 워크로드 배포는 Helm/ArgoCD 영역이고 이 레포 범위가 아니다.

## 확장

**변수 추가** — 지금은 `inventory.ini` 의 `[k3s:vars]` 에 있다. 리스트/중첩이 필요하면
`group_vars/k3s.yml` 로 옮긴다 (파일명 = 그룹명, 우선순위 더 높음).
`k3s_server_args`, `extra_packages` 는 site.yml 이 이미 받도록 해뒀다.

```yaml
# group_vars/k3s.yml
k3s_server_args: "--disable traefik --disable servicelb"
extra_packages: [stern, yq]
```

**호스트마다 비번이 다르면** — `ask_pass` 는 프롬프트 한 번으로 전 호스트에 같은 값을 쓴다.
다르면 vault 를 써라. 평문으로 적으면 git 과 로그에 남는다.

```bash
uv run ansible-vault create group_vars/k3s/vault.yml   # ansible_password 등
uv run ansible-playbook site.yml --ask-vault-pass
```

**앱 추가** — 4번 play 에 task 를 추가한다. 패턴은 두 가지다.

```yaml
# 설치 스크립트
- name: 무언가 설치
  ansible.builtin.shell: |
    set -o pipefail
    curl -fsSL https://example.com/install.sh | sh
  args:
    creates: /usr/local/bin/무언가
    executable: /bin/bash

# GitHub 릴리스 tarball
- name: 무언가 설치
  ansible.builtin.unarchive:
    src: "https://github.com/org/repo/releases/download/{{ ver }}/x_Linux_amd64.tar.gz"
    dest: /usr/local/bin
    remote_src: true
    include: [무언가]
    mode: "0755"
    creates: /usr/local/bin/무언가
```

`set -o pipefail` 은 선택이 아니다. 없으면 `curl` 이 실패해도 `sh` 가 빈 입력을 받고
0 을 반환해서 **성공으로 뜨는데 실제로는 안 깔린다.**

## 검증 / 트러블슈팅

서버 없이 확인 가능한 것:

```bash
uv run ansible-playbook site.yml --syntax-check
uv run ansible-inventory --graph --vars
uv run ansible-lint
```

`--check --diff` 는 drift 감지에 쓸 수 있지만 `shell` task 가 skip 되므로
이 플레이북에서는 신뢰도가 낮다 (`terraform plan` 과 다르다).

| 에러 | 해결 |
|---|---|
| `you must install the sshpass program` | `sudo apt install sshpass` |
| `Permission denied (publickey)` | 서버가 비번 인증 차단. SE 에게 공개키 등록 요청 |
| `Host key verification failed` | `ssh-keyscan -H <ip> >> ~/.ssh/known_hosts` |
| `UNREACHABLE` / timeout | 손으로 `ssh -v` 먼저 해봐라 |
| `/usr/bin/python: not found` | inventory 에 `ansible_python_interpreter=/usr/bin/python3` |
| sudo 관련 모듈 에러 | `ansible.cfg` 에서 `pipelining = False` |
| agent join 실패 | server 의 6443/TCP, 8472/UDP 확인 |
| 매번 `changed` | `creates:` 빠졌는지 확인 |

k3s 로그는 서버에서 `journalctl -u k3s -f` (agent 는 `k3s-agent`).
