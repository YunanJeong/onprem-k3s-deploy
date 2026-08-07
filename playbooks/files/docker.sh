# 
# /etc/docker/daemon.json  # Registry and Logging settings  
# 
# 로그 설정 없을시 disk full 가능성 있음
# docker-k3s연동시 로그 max-size는 10m 권장(kubelet 기본값)
# docker와 k3s의 max-size가 다를시, docker 설정대로 로그가 정상처리되지만, 불필요한 에러메시지가 지속 발생함
  # https://github.com/rancher/rancher/issues/39819#issuecomment-1472278470
URL_DOCKER=${URL_DOCKER:-"docker.wai"}  # If not set, default used
cat <<EOF > /tmp/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "100"
  },
  "insecure-registries": ["${URL_DOCKER}"],
  "registry-mirrors": ["http://${URL_DOCKER}"]
}
EOF

sudo mkdir -p /etc/docker
sudo mv /tmp/daemon.json /etc/docker/daemon.json

#
# Install
#
# https://docs.docker.com/engine/install/ubuntu/
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Non-root settings
# https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
# sudo groupadd docker
sudo usermod -aG docker $USER
# newgrp docker