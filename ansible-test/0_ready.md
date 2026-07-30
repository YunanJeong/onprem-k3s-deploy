# Ansible 사전 준비 작업
## 머신 준비(EC2로 시작)
- 인스턴스에 ssh, icmp 허용하는 보안그룹 필요
- Ansible 관련 블로그에서 초기설정시 핑테스트 예제를 많이 보여주는데, icmp 허용안하면 Fail 된다.
- [AWS EC2로 앤서블 테스트 블로그 사례](https://jojoldu.tistory.com/432)

## SSH 설정
0. Control Node로 쓸 호스트에 Ansible 설치
    - `$ ansible localhost -m ping`(ansible로 로컬에 핑 테스트)로 정상설치 확인
        - 이는 'ping' 모듈을 가져와 쓴 것이고, 인자가 localhost다.
1. Control Node에서 `/etc/ansible/hosts` 파일 생성
```
# /etc/ansible/hosts
# 다음과 같이 Managed Host들의 ip를 적어준다.
# hosts에서 #으로 주석쓰기 가능
192.168.0.2
192.168.0.3
```

2. Control Node에서 `$ ssh-keygen -t rsa`로 private key, public key 파일 생성
    - `-t rsa`: 암호화 방식 rsa 선택을 의미
    - 다음과 같이 추가 입력 요구가 있지만, 일반 사용시 그냥 엔터로 모두 넘어가도록 한다.
        - `Enter file in which to save the key (): `: 경로 포함 파일명 입력자리
            - 넘어가면 디폴트 경로, 파일명(id_rsa)으로 생성
            - **디폴트 파일명이 아닌경우 ansible 연결테스트 실패 이슈 있음**
        - `Enter passphrase: `: key의 비밀번호를 추가 원할 시 사용
    - root, user 권한 관련
        - `$sudo ssh-keygen -t rsa`의 디폴트 경로(`/root/.ssh/`)는 `$sudo ansible`에서 참조
        - `$ssh-keygen -t rsa`의 디폴트 경로(`~/.ssh/`)는 `$ansible`에서 참조
        - 키 생성 시부터 위와 같이  권한을 고려한 작업 필요
        - 가급적 모든 작업을 user 권한으로 진행하는 것이 이슈가 적다.
            - apt로 설치 후 유저 권한 ansible이 안되면, pip로 설치해보자.
    ```
    - EC2로 초기 셋업 및 테스트시 권장 권한 (경우에 따라 다를 수 있음)
        - Control Node(Ansible)에서는 root 또는 user 권한 중 하나만 골라 모든 관련 작업 처리
        - Managed Node에서는 모든 작업을 user 권한 사용
            - 어차피 인스턴스 생성시 만든 user계정으로 ssh 접속하고, Managed Node내 root권한 필요시 sudo 커맨드쓰면 되니까.
    ```

3. Control Node의 `/root/.ssh/` 또는 `~/.ssh/` 경로에서 키 파일 생성 확인
    - id_rsa.pub: public key, 다른 경로로 옮겨도 됨
    - id_rsa: private key. ssh 연결시 해당 경로에 있어야 함

4. public key의 내용 "텍스트 전체"를 복사하여, Managed Node의 `~/.ssh/authorized_keys`에 추가
    - 혹시 차단 풀어서 root 계정 접속할 경우, `/root/.ssh/authorized_keys`
    - authorized_key 기존 내용의 "다음줄"에 입력하면 된다.
    - 다음과 같이 redirect 하면 편하다.
    ```
    $ echo {...pub 내용...} >> ~/.ssh/authorized_keys
    ```
5. Control Node에서 `$ ansible all -m ping`으로 정상동작 확인
    - `/etc/ansible/hosts`의 모든 node에 핑테스트
    - ssh 설정이 잘못되면 fail
    - ssh, icmp 네트워크 차단되어있으면 fail
    - Managed Node의 `~/.ssh/authorized_keys` 파일권한이 root면 denied

6. 별도 인벤토리 파일 사용해보기
    - 위는 글로벌 작업경로(`/etc/ansible/`)를 사용한 예제이다.
    - ansible 실제 사용시에는, 편의를 위해 별도 인벤토리 파일을 사용한다.
    - 아래처럼 파일생성 후 `$ ansible myserver -i ~/server.yml -m ping`으로 동일한 핑테스트 가능
    ```
    # ~/server.yml
    [myserver]
    192.168.0.2
    192.168.0.3
    ```


---
## SSH 설정 참고 사항
- Ansible은 ssh로 다른 호스트들을 관리한다. ssh 사전 설정이 필요한데, Ansible 관련 글들은 이 부분을 너무 간략히 설명한다.
- ssh 설정시 헷갈리는 부분 or 알면 좋은 내용을 여기 정리한다.
- 참고: [ssh 상세설명](https://danthetech.netlify.app/Backend/configure-ssh-key-based-authentication-on-a-linux-server)

### 비대칭키 활용(private key와 public key)
- ssh 접속인증방법은 다양
    - 비대칭키: **Ansbile ssh의 일반적 채택 방식**
    - userid-password 로그인 인증: 상대적으로 보안이 약함
- 비대칭키는 생성 시부터 private key, public key의 쌍으로 구성됨
    - private key는 클라이언트에,
    - public key는 서버에 배치되는 용도다.
- 인증절차는 다음과 같다.
    1. 클라이언트는 서버에 접속요청하면서 자신의 key(private)를 제시
    2. 서버는 제시받은 key(private)와 자신의 key(public)를 비교
    3. 두 key가 매칭되는 쌍이 맞으면 접속 허가
- private key는 열쇠와 같은 것이므로, 보안 및 보관이 매우 중요
- 따라서 Ansible 사전준비시 다음과 같은 작업이 필요
    1. ssh접속용 비대칭키를 생성하고,
    2. private key 파일을 Control Node(클라이언트)에 배치
    3. public key 파일을 Managed Node(서버)에 배치


