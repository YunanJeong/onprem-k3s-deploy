# ansible-test

# 설치
- [앤서블 설치 및 시작(심플)](https://league-cat.tistory.com/376)

## Python
    $ pip install ansible
    $ pip install ansible==2.10.7
- pip으로 설치. Ansible 버전따라 syntax가 다르므로, 버전 별 관리시 유용
- 파이썬 패키지 취급이므로, pyenv 등 격리환경에 종속될 수 있다.

## Ubuntu
    $ sudo apt update
    $ sudo apt install ansible

## CentOS
    $ yum install -y ansible
- Ansible과 CentOS 모두 RedHat회사에서 관리하므로, Ansible은 CentOS 기준 문서가 많다. 그러나 설치방법에 관계없이 용법이 거의 동일하므로 자신에게 편한 방법을 택하면 된다.
- 참고: 다수 개발자들에게 익숙한 Ubuntu로 CentOS의 점유율이 옮겨가는 중이다. CentOS는 서버 영역에서 많이 쓰이지만, 클라우드 서비스, DevOps, IaC 개념 등 발달로 서버 구축시 개발 비중이 커졌기 때문이다.

## MacOS
    $ brew install ansible

# 용어 및 개념
- Control Node
    - Ansible이 설치 및 실행되는 호스트
    - 다른 호스트들을 관리하는 호스트
- Managed Node
    - 관리 대상 호스트
- Inventory (hosts)
    - Managed Node의 목록 및 정보를 기술한 파일 (각각 IP, 변수, 호스트 정보 등)
    - Control Node의 `/etc/ansible/hosts` 파일을 생성하여 Managed Node들의 정보를 기술할 수 있다. 
        - `/etc/ansible/`은 Ansible의 글로벌 작업 경로이고, ansible 사용시 자동 참조
    - `$ ansible -i {file}`: 별도 인벤토리 파일을 참조할 수 있다. `/etc/ansible/hosts` 보다 우선시된다.
        - file자리에는 yml, ini 등을 쓸 수 있다.
- Module
- Task
- Playbook


# Ansible 시작할 때 사전 준비 작업
- 다수 블로그에서 인프라 환경 구성 및 ssh 연결 부분을 간략히 언급하고 넘어간다.
- 개인 구축 환경의 소소한 차이로 인해, 초기 셋업 시간이 많이 소요될 수 있다.
- 다음 정리내용을 먼저 읽고, 다른 좋은 Ansible 튜토리얼들을 진행하도록 하자.
    - [내가 필요한 사전작업내용 정리](https://github.com/YunanJeong/ansible-test/blob/main/0_ready.md)
    - Ansible 테스트시 내가 사용했던 환경
        - 로컬 wsl (Control) -> EC2 ubuntu 여러대 (Managed)
        - 또는, EC2 ubuntu 1대 (Control) -> EC2 ubuntu 여러대 (Managed)

# 참고 튜토리얼
- [앤서블 시작하기(개념 등 설명 훌륭, 전반적으로 튜토리얼시 좋음)](https://wikidocs.net/130113)
