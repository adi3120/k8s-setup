To set up a Kubernetes cluster using `kubeadm` on your Ubuntu 22 VMs, follow these steps. We'll assume you want to use `10.197.226.100` as the master node and `10.197.226.103` and `10.197.226.104` as the worker nodes.
 
### **Step 1: Prepare your Ubuntu VMs**
 
1. **Update your system on all nodes:**
   On all three VMs, update the system and install essential packages:
 
   ```bash
   sudo apt update
   sudo apt upgrade -y
   sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
   ```
 
2. **Disable Swap Memory** (Kubernetes doesn't support swap):
   Run this command on all three VMs to disable swap:
 
   ```bash
   sudo swapoff -a
   swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab
   ```
 
   To make this change permanent, comment out or remove any swap entries from `/etc/fstab` by opening the file and editing:
 
   ```bash
   sudo nano /etc/fstab
   ```
 
   Look for a line that references swap and either comment it out with `#` or remove it completely.
 
3. **Set hostname on each node** to reflect their roles:
 
   On the master node (`10.197.226.100`):
 
   ```bash
   sudo hostnamectl set-hostname master-node
   ```
 
   On the worker node 1 (`10.197.226.103`):
 
   ```bash
   sudo hostnamectl set-hostname worker-node-1
   ```
 
   On the worker node 2 (`10.197.226.104`):
 
   ```bash
   sudo hostnamectl set-hostname worker-node-2
   ```
 
4. **Update the `/etc/hosts` file** on all nodes to map IP addresses to hostnames for all three nodes:
 
   Edit the `/etc/hosts` file on all nodes:
 
   ```bash
   sudo nano /etc/hosts
   ```
 
   Add the following entries:
 
   ```
   10.197.226.100 master-node
   10.197.226.103 worker-node-1
   10.197.226.104 worker-node-2
   ```
 
   This ensures that all nodes can resolve each other's hostnames.
 
---
 
### **Step 2: Install Docker on all nodes**
 
Kubernetes requires a container runtime. We'll install Docker on all nodes.
 
1. **Install Docker on all nodes:**
 
   ```bash
   sudo apt update
   sudo apt install -y docker.io
   sudo systemctl enable docker
   sudo systemctl start docker
   ```
 
2. **Add your user to the `docker` group** (optional but useful):
 
   ```bash
   sudo usermod -aG docker $USER
   ```
 
   Log out and log back in to apply the changes.
 
3. **Verify Docker installation:**
   Run the following command on all nodes:
 
   ```bash
   sudo docker --version
   ```
 
---
 
### **Step 3: Install `kubeadm`, `kubelet`, and `kubectl` on all nodes**
 
These instructions are for Kubernetes v1.35.

Update the apt package index and install packages needed to use the Kubernetes apt repository:

```bash
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```
Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories so you can disregard the version in the URL:

```bash
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```
Note:
In releases older than Debian 12 and Ubuntu 22.04, directory /etc/apt/keyrings does not exist by default, and it should be created before the curl command.
Add the appropriate Kubernetes apt repository. Please note that this repository have packages only for Kubernetes 1.35; for other Kubernetes minor versions, you need to change the Kubernetes minor version in the URL to match your desired minor version (you should also check that you are reading the documentation for the version of Kubernetes that you plan to install).

```bash
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

(Optional) Enable the kubelet service before running kubeadm:

```bash
sudo systemctl enable --now kubelet
```
 
4. **Check if `kubeadm` is installed correctly:**
   Run on all nodes:
 
   ```bash
   kubeadm version
   ```
 
---
```bash
sudo mkdir -p /etc/systemd/system/containerd.service.d
sudo nano /etc/systemd/system/containerd.service.d/http-proxy.conf
```

```
[Service]
Environment="HTTP_PROXY=http://proxy-wsa.esl.cisco.com:80"
Environment="HTTPS_PROXY=http://proxy-wsa.esl.cisco.com:80"
Environment="NO_PROXY=localhost,127.0.0.1,10.197.226.0/24,10.96.0.0/12,192.168.0.0/16"
```
```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

sudo systemctl restart containerd

systemctl show containerd | grep -i proxy
```

---
 
### **Step 4: Set up the Kubernetes Master Node (`10.197.226.100`)**
 
On the master node (`10.197.226.100`):
 
1. **Initialize the Kubernetes cluster using `kubeadm`:**
 
   Run the following command to initialize the cluster:
 
   ```bash
   sudo kubeadm init --pod-network-cidr=10.244.0.0/16
   ```
 
   * The `--pod-network-cidr=10.244.0.0/16` flag specifies the CIDR block for the pod network (useful for Flannel or Calico network solutions).
 
2. **Copy the kubeconfig file:**
 
   After successful initialization, you should see an output containing a command to set up the kubeconfig for `kubectl`. Follow the instructions to configure your user to be able to run `kubectl` commands as root.
 
   Run the following command to copy the kubeconfig file for `kubectl`:
 
   ```bash
   mkdir -p $HOME/.kube
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```
 
3. **Install a pod network (e.g., Flannel or Calico)**:
 
   To enable communication between the nodes, you need to install a network plugin. Here, we’ll use Flannel, but you can choose another one (Calico, Weave, etc.).
 
   For Flannel, run the following command on the master node:
 
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
   ```
 
---
 
### **Step 5: Join Worker Nodes to the Cluster**

eg

```bash
kubeadm join 10.197.226.100:6443 --token knqtpw.t02uinpb645d3jmc \
	--discovery-token-ca-cert-hash sha256:6ba65e0269b01c0f610ace53ef1eec8de5f67ebe61023547eda19526037cd2eb 
```


1. **Get the join token from the master node:**
 
   After the master node initializes, `kubeadm` will provide you with a command that allows the worker nodes to join the cluster. It looks something like this:
 
   ```
   kubeadm join 10.197.226.100:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
   ```
 
   Copy this command and execute it on each of your worker nodes (`10.197.226.103` and `10.197.226.104`).
 
2. **Run the join command on each worker node:**
 
   On worker node 1 (`10.197.226.103`):
 
   ```bash
   sudo kubeadm join 10.197.226.100:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
   ```
 
   On worker node 2 (`10.197.226.104`):
 
   ```bash
   sudo kubeadm join 10.197.226.100:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
   ```
 
---
 
### **Step 6: Verify the Cluster**
 
1. **Check the status of the nodes:**
 
   On the master node, you can check the status of all nodes:
 
   ```bash
   kubectl get nodes
   ```
 
   You should see all three nodes listed as `Ready` after a few minutes.
 
---

```bash
cilium install \
  --set proxy.enabled=true \
  --set extraEnv[0].name=HTTP_PROXY \
  --set extraEnv[0].value=http://proxy-wsa.esl.cisco.com:80 \
  --set extraEnv[1].name=HTTPS_PROXY \
  --set extraEnv[1].value=http://proxy-wsa.esl.cisco.com:80 \
  --set extraEnv[2].name=NO_PROXY \
  --set extraEnv[2].value=localhost,127.0.0.1,10.197.226.0/24,10.96.0.0/12
```

--- 
### **Step 7: Install a Kubernetes Dashboard (Optional)**
 
If you'd like to set up a Kubernetes Dashboard for managing the cluster, you can install it by running:
 
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended.yaml
```
 
Then, to access the dashboard, you'll need to create a service account and obtain a token for login. Check the official Kubernetes Dashboard documentation for the full steps.
 
---
 
### **Step 8: Final Notes**
 
* Make sure your VMs can communicate over the necessary ports (especially for the Kubernetes API and node communication).
* The Flannel network plugin assumes that your pods are assigned IPs in the `10.244.0.0/16` range. If you use a different network plugin, adjust the CIDR block accordingly.
* Keep the Kubernetes documentation handy for troubleshooting or further configuration.
 
That should set up your three-node Kubernetes cluster!