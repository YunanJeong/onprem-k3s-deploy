# onprem-k3s-deploy

Ansible 로 K3s 클러스터 구축을 자동화한다.
설치·HA·업그레이드·제거는 공식 collection [`k3s-io/k3s-ansible`](https://github.com/k3s-io/k3s-ansible)
(`k3s.orchestration`) 이 담당하고, 이 레포는 **용례별 인벤토리**를 관리한다.

| 용례 | 구성 |
|---|---|
| `single` | server 1대 |
| `ha` | server 3대, embedded etcd HA |

## 처음 실행

아래는 `ha` 기준이다. 1대 구성은 `ha` → `single` 로 바꾼다.

```bash
# 1. 도구 설치 (최초 1회)
uv sync
sudo apt install sshpass                    # 비번으로 SSH 접속할 때만

# 2. 인벤토리 작성 — IP 와 ansible_user 를 실제 값으로
cp inventories/ha/hosts.yml.example inventories/ha/hosts.yml
vi inventories/ha/hosts.yml

# 3. 연결 확인 (선택) — 전 노드 SUCCESS 나와야 다음으로
#    필수는 아니지만, 첫 구축이면 SSH 문제를 먼저 걸러낼 수 있다
#    k3s_cluster : 대상 그룹 이름. 인벤토리에 정의된 전체 노드 그룹
#    -m ping     : 플레이북 없이 모듈 하나만 실행 (명령이 ansible-playbook 이 아니다)
#                  ping 모듈 = SSH 접속 + 리모트 Python 실행 확인 (ICMP 아님)
#    -i          : 인벤토리 파일 지정
uv run ansible k3s_cluster -m ping -i inventories/ha/hosts.yml

# 4. 구축
#    k3s.orchestration.site : 실행할 플레이북. collection 의 site 플레이북
#    -i                     : 인벤토리 파일 지정 (어느 서버에 적용할지)
uv run ansible-playbook k3s.orchestration.site -i inventories/ha/hosts.yml

# 5. 확인 (server 노드에서)
ssh <server1_ip>
kubectl get nodes
```

접속 관련:

- 3번에서 막히면 전부 SSH 문제다. 플레이북으로 해결되지 않는다
- 비번은 두 번 물어본다(SSH → sudo). 같으면 두 번째는 엔터
- `Host key verification failed` → 내 PC 의 `~/.ssh/known_hosts` 에 서버가 없다(최초 접속 필요).
  `ssh-keyscan -H <IP> >> ~/.ssh/known_hosts` 로 등록하거나, 명령 앞에
  `ANSIBLE_HOST_KEY_CHECKING=False` 를 붙여 검사를 끈다

현재 사용중인 `공식 collection playbook은 셋업완료 후, 로컬 kubectl에서 접근가능하도록 kubeconfig 컨텍스트 파일을 자동처리`해준다.

- 내 PC 에 `kubectl` 이 있을 때만 가져온다. 없으면 아무것도 하지 않는다
- 인벤토리에 `kubeconfig: <경로>` 를 지정하면 그곳에 복사만 한다
- 지정하지 않으면 `~/.kube/config` 에 `k3s-ansible` 컨텍스트로 병합된다(기존 컨텍스트는 유지).
  - 이후 `kubectl config use-context k3s-ansible` 로 전환해서 사용가능
  - 단, collection에서 리셋용 플레이북인 `reset.yaml`를 적용하더라도, 원격환경만 되돌릴뿐 로컬 kubeconfig파일에서 내용은 그대로라서 수동 제거 필요한 점 참고

## 그 밖의 작업

```bash
# 제거 (테스트용 배포 제거 라던지 등등 필요시 사용)
uv run ansible-playbook k3s.orchestration.reset  -i inventories/ha/hosts.yml
```
```bash
# 부가 도구(helm, k9s) — k3s 구축 후. 선택사항
# 공식 collections에서 제공하는 것외에 추가배포할 것들을 모은 커스텀 플레이북 실행
uv run ansible-playbook playbooks/extras.yml -i inventories/ha/hosts.yml
```
```bash
# 재부팅
uv run ansible-playbook k3s.orchestration.reboot -i inventories/ha/hosts.yml

# 문법 검사
uv run ansible-playbook k3s.orchestration.site -i inventories/ha/hosts.yml --syntax-check

# 업그레이드 — 인벤토리의 k3s_version 을 바꾼 뒤 적용
# HA 재실행·업그레이드에는 `--forks=1`** 을 붙인다. 한 대씩 처리해서 etcd 쿼럼을 지킨다.
uv run ansible-playbook k3s.orchestration.upgrade -i inventories/ha/hosts.yml --forks=1
```

**

## 알아둘 것

**HA 토글은 없다.** `server` 그룹의 호스트 수로 collection 이 판별한다. 2대 이상이면
자동으로 embedded etcd HA 가 되고, 첫 호스트가 `cluster-init`, 나머지가 합류한다.
etcd 쿼럼 때문에 server 는 홀수(3, 5, 7)여야 한다.

**`ha` 는 3대 모두 server 다.** 워커를 붙이려면 인벤토리의 `agent` 블록 주석을 풀고
IP 를 넣는다.

**용례 추가**는 `inventories/<이름>/hosts.yml.example` 을 하나 더 만들면 된다.
플레이북은 collection 것을 공용으로 쓴다.

**이름은 바꾸면 안 된다.** 그룹 이름(`k3s_cluster`, `server`, `agent`)과
변수 이름(`k3s_version`, `token`, `api_endpoint` 등)은 collection 규약이다.

**리모트 요구사항**은 SSH + Python 3 + sudo 뿐이다. 에이전트 설치는 없다.

**collection 은 `collections/` 에 커밋돼 있어** 따로 받지 않아도 된다.
버전을 올릴 때만 `requirements.yml` 을 수정하고 `ansible-galaxy collection install
-r requirements.yml --force` 를 실행한다.

## Collection 이란

Ansible 의 배포 단위다. 파이썬 패키지나 Terraform provider 에 해당한다.

- **받기** — `ansible-galaxy collection install`. 받을 버전은 `requirements.yml` 에
  적는다 (`uv.lock` 과 같은 역할).
- **위치** — `ansible.cfg` 의 `collections_path = ./collections` 에 따라 프로젝트 안에
  격리된다. 전역(`~/.ansible/`)에 깔면 다른 프로젝트와 버전이 섞인다.
- **호출** — `namespace.name.playbook` 형태(FQCN). `k3s.orchestration.site` 는
  `k3s` 네임스페이스의 `orchestration` collection 에 있는 `site` 플레이북이다.

## 오프라인(에어갭) 배포

`collections/` 를 커밋해뒀으므로 레포만 옮기면 collection 은 해결된다.
의존성인 `community.general` / `ansible.posix` 는 `ansible` 패키지에 번들되어 있다.

남는 것은 두 가지다.

- **ansible 자체** — 인터넷 없는 곳에서 `uv sync` 가 안 된다. `.venv` 를 통째로 옮기거나
  wheel 을 미리 받아 함께 옮긴다.
- **k3s 바이너리·이미지** — 기본 동작은 대상 노드(Ansible Managed Node)가 `https://get.k3s.io` 로 나가는 방식이라
  실패한다. 인벤토리에 `airgap_dir` 를 지정하면 **로컬작업PC(Ansible Control Node)에 미리 둔 파일을 대상
  노드로 밀어넣는 방식**으로 바뀐다. 그 디렉터리에 k3s 바이너리·이미지 tarball·
  `k3s-install.sh` 를 넣어둬야 한다. **이 레포에는 아직 설정하지 않았다.**

## 디렉터리

```
onprem-k3s-deploy/
├── requirements.yml           # collection 과 버전(1.2.1) 고정
├── ansible.cfg                # 도구 설정. 이 이름만 자동으로 읽힌다
│
├── inventories/               # 용례별 대상 서버 목록 — 여기만 고치면 된다
│   ├── single/
│   │   └── hosts.yml.example  #   템플릿만 커밋. hosts.yml 로 복사해서 실제 값 입력
│   └── ha/
│       └── hosts.yml.example
│
├── playbooks/
│   └── extras.yml             # 부가 도구(helm, k9s). k3s 와 다른 계층
│
├── collections/               # 받아둔 collection. 오프라인 배포용으로 커밋한다
│   └── ansible_collections/k3s/orchestration/
│       ├── playbooks/         #   site / upgrade / reset / reboot ← 실행 대상
│       └── roles/             #   k3s_server, prereq, airgap 등 내부 구현
│
├── pyproject.toml             # ansible 을 uv 로 설치하기 위한 정의
├── uv.lock                    # 파이썬 패키지 버전 고정
├── .gitignore                 # hosts.yml, kubeconfig 등 커밋 금지 대상
└── ansible-test/              # 기존 Ansible 학습 정리 (배포와 무관)
```

복사한 `hosts.yml` 에는 실제 IP·계정이 들어가고 gitignore 로 막혀 있다.
