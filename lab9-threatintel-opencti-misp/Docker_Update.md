#Remove the old Docker packages (optional but keeps the repo clean):
```
sudo yum remove docker \
  docker-client docker-client-latest docker-common \
  docker-latest docker-latest-logrotate docker-logrotate docker-engine
```
#Install Docker CE from the official repo (which includes buildx ≥ 0.17):
```
sudo amazon-linux-extras disable docker
sudo yum install -y yum-utils
```
#opcion 1
```
sudo yum-config-manager \
  --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
#opcion2
```
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo sed -i 's#$releasever#7#g' /etc/yum.repos.d/docker-ce.repo
```

#Clear metadata and install Docker CE + buildx:
```
sudo yum clean all
sudo yum makecache
```
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

# Enable EPEL for Amazon Linux 2 so we can satisfy the missing deps

```
sudo amazon-linux-extras install -y epel
```

# Install the dependencies Docker CE expects
```
sudo yum install -y \
  container-selinux \
  fuse-overlayfs \
  slirp4netns
```
# Now install Docker CE and plugins from the Docker repo

```
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#If container-selinux isn’t available in your current repos, fetch it directly from CentOS 7:

```
sudo install -y \
  https://download.docker.com/linux/centos/7/x86_64/stable/Packages/container-selinux-2.20220613-1.2.el7.noarch.rpm \
  https://download.docker.com/linux/centos/7/x86_64/stable/Packages/fuse-overlayfs-0.7.6-1.el7.x86_64.rpm \
  https://download.docker.com/linux/centos/7/x86_64/stable/Packages/slirp4netns-1.2.0-2.el7.x86_64.rpm
```

#Then run
```

sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
docker buildx version   # should show v0.17+ now
```



#Restart Docker and enable it:
```
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # log out/in after this
```
#Verify buildx:
```
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/buildx/releases/download/v0.17.1/buildx-v0.17.1.linux-amd64 \
  -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
docker buildx version  # verify
```
