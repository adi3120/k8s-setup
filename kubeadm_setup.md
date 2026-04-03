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
 
1. **Add the Kubernetes apt repository:**
 
   On all nodes, run the following commands to add Kubernetes' official repository and install the required tools:
 
   ```bash
   sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
   ```
 
   Then add the Kubernetes apt repository:
 
   ```bash
   sudo apt-add-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
   ```
 
2. **Install the necessary Kubernetes components:**
 
   ```bash
   sudo apt update
   sudo apt install -y kubeadm kubelet kubectl
   ```
 
3. **Hold the versions of these packages:**
 
   To prevent automatic updates to `kubeadm`, `kubelet`, and `kubectl` that might break the cluster:
 
   ```bash
   sudo apt-mark hold kubeadm kubelet kubectl
   ```
 
4. **Check if `kubeadm` is installed correctly:**
   Run on all nodes:
 
   ```bash
   kubeadm version
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