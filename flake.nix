{
  description = "virtual environments";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.devshell.url = "github:numtide/devshell";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs @ {
    self,
    flake-parts,
    devshell,
    nixpkgs,
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        devshell.flakeModule
      ];

      systems = ["x86_64-linux"];

      perSystem = {pkgs, ...}: {
        devshells.default = {
          packages = with pkgs; [
            k9s
            kubectl
            clusterctl
            kubernetes-helm
            kind
            cilium-cli
            helmfile
          ];
          commands = [
            {
              package = pkgs.writeShellScriptBin "setup-kind" ''
                set -e
                if kind get clusters | grep -q "hetzner"; then
                  echo "Cluster 'hetzner' exists, ensuring it's running..."
                  if ! docker ps -q -f "name=hetzner-control-plane" | grep -q .; then
                    echo "Restarting stopped cluster..."
                    docker start hetzner-control-plane
                  fi
                else
                  echo "Creating cluster 'hetzner'..."
                  kind create cluster --name hetzner
                fi
                kind get kubeconfig --name hetzner > nix/kubeconfig
                export KUBECONFIG=$(pwd)/nix/kubeconfig
                echo "KUBECONFIG set to $KUBECONFIG"
              '';
              name = "1-setup-kind";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "setup-management-cluster" ''
                KUBECONFIG=$(pwd)/nix/kubeconfig
                if [ ! -f "$KUBECONFIG" ]; then
                  echo "Error: kubeconfig not found. Run setup-kind first."
                  exit 1
                fi
                echo "Initializing management cluster with clusterctl (insecure mode)..."
                clusterctl init --kubeconfig "$KUBECONFIG" --core cluster-api --bootstrap kubeadm --control-plane kubeadm --infrastructure hetzner
              '';
              name = "2-setup-management-cluster";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "create-secret" ''
                KUBECONFIG=$(pwd)/nix/kubeconfig
                kubectl create secret generic hetzner --from-literal=hcloud=$HCLOUD_TOKEN
                kubectl patch secret hetzner -p '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'

              '';
              name = "3-create-secret";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "generate-cluster-yaml" ''
                set -e
                # Management cluster context
                export KUBECONFIG=$(pwd)/nix/kubeconfig
                export HCLOUD_SSH_KEY="hetzner-cluster-key"
                # Ensure HCLOUD_SSH_KEY is set (name from Hetzner Cloud Console)
                if [ -z "$HCLOUD_SSH_KEY" ]; then
                  echo "Error: HCLOUD_SSH_KEY not set. Export it with your Hetzner SSH key name (e.g., 'my-hetzner-key')."
                  exit 1
                fi
                echo "Generating my-cluster.yaml with HCLOUD_SSH_KEY=$HCLOUD_SSH_KEY..."
                clusterctl generate cluster my-cluster \
                  --infrastructure hetzner:v1.0.0-beta.35 \
                  --kubernetes-version v1.29.4 \
                  --control-plane-machine-count=1 \
                  --worker-machine-count=1 > nix/my-cluster.yaml
              '';
              name = "4-generate-cluster-yaml";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "provision-cluster" ''
                set -e

                # Management cluster context
                export KUBECONFIG=$(pwd)/nix/kubeconfig
                if [ ! -f "$KUBECONFIG" ]; then
                  echo "Error: kubeconfig not found. Run setup-kind first." | tee -a nix/provision.log
                  exit 1
                fi
                if [ ! -f "nix/my-cluster.yaml" ]; then
                  echo "Error: my-cluster.yaml not found. Run generate-cluster-yaml first." | tee -a nix/provision.log
                  exit 1
                fi

                echo "Applying cluster configuration..." | tee -a nix/provision.log
                kubectl apply -f nix/my-cluster.yaml >> nix/provision.log 2>&1

                # Wait for control plane (management cluster context)
                echo "Waiting for control plane to initialize..." | tee -a nix/provision.log
                until kubectl get kubeadmcontrolplane my-cluster-control-plane -o jsonpath='{.status.ready}' | grep -q "true"; do
                  echo "Control plane not ready, checking in 20s..." | tee -a nix/provision.log
                  kubectl get kubeadmcontrolplane my-cluster-control-plane >> nix/provision.log 2>&1
                  sleep 20
                done
                echo "Control plane initialized!" | tee -a nix/provision.log

                # Wait for Hetzner kubeconfig
                echo "Waiting for kubeconfig..." | tee -a nix/provision.log
                until clusterctl get kubeconfig my-cluster > nix/kubeconfig.hetzner.yaml 2>/dev/null; do
                  echo "Kubeconfig not ready, retrying in 20s..." | tee -a nix/provision.log
                  sleep 20
                done
                chmod 600 nix/kubeconfig.hetzner.yaml

                # Switch to Hetzner cluster
                export KUBECONFIG=$(pwd)/nix/kubeconfig.hetzner.yaml
                echo "Switched to Hetzner cluster: $KUBECONFIG" | tee -a nix/provision.log

                # Wait for API server
                echo "Waiting for API server..." | tee -a nix/provision.log
                until kubectl cluster-info >/dev/null 2>&1; do
                  echo "API server not reachable, retrying in 20s..." | tee -a nix/provision.log
                  kubectl cluster-info >> nix/provision.log 2>&1
                  sleep 20
                done
                echo "API server ready!" | tee -a nix/provision.log

                # Add the Hetzner secret
                #kubectl create secret generic hcloud --from-literal=hcloud=$HCLOUD_TOKEN
                #kubectl patch secret hcloud -p '{"metadata":{"labels":{"clusterctl.cluster.x-k8s.io/move":""}}}'

                # Install Hetzner CCM
                echo "Installing Hetzner Cloud Controller Manager..." | tee -a nix/provision.log
                kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm.yaml >> nix/provision.log 2>&1
                kubectl -n kube-system patch deployment hcloud-cloud-controller-manager \
                  -p '{"spec":{"template":{"spec":{"containers":[{"name":"hcloud-cloud-controller-manager","env":[{"name":"HCLOUD_TOKEN","valueFrom":{"secretKeyRef":{"name":"hetzner","key":"hcloud"}}}]}]}}}}' \
                  >> nix/provision.log 2>&1

                # Install Cilium CNI
                echo "Installing Cilium CNI..." | tee -a nix/provision.log
                helm repo add cilium https://helm.cilium.io/
                helm repo update
                helm install cilium cilium/cilium --namespace kube-system \
                  --version 1.15.3 \
                  --set ipam.mode=cluster-pool \
                  --set clusterPoolIPv4PodCIDRList={10.0.0.0/8} >> nix/provision.log 2>&1

                # Wait for Cilium pods
                echo "Waiting for Cilium pods..." | tee -a nix/provision.log
                until kubectl get pods -n kube-system -l k8s-app=cilium | grep -q "Running"; do
                  echo "Cilium pods not running, checking in 10s..." | tee -a nix/provision.log
                  kubectl get pods -n kube-system -l k8s-app=cilium >> nix/provision.log 2>&1
                  sleep 10
                done
                kubectl -n kube-system rollout status daemonset cilium >> nix/provision.log 2>&1

                # Wait for node readiness
                echo "Waiting for node to be Ready..." | tee -a nix/provision.log
                until kubectl get nodes | grep -q "Ready"; do
                  echo "Node not ready, checking in 20s..." | tee -a nix/provision.log
                  kubectl get nodes -o wide >> nix/provision.log 2>&1
                  sleep 20
                done

                # Final status
                echo "Cluster provisioned successfully!" | tee -a nix/provision.log
                kubectl get nodes -o wide >> nix/provision.log 2>&1
                kubectl get pods -A >> nix/provision.log 2>&1
                echo "Use: export KUBECONFIG=$(pwd)/nix/kubeconfig.hetzner.yaml" | tee -a nix/provision.log
              '';
              name = "5-provision-cluster";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "move-provisioning-to-cluster-itself" ''
                clusterctl init --core cluster-api --bootstrap kubeadm --control-plane kubeadm --infrastructure hetzner
                export KUBECONFIG=$(pwd)/nix/kubeconfig
                clusterctl move --to-kubeconfig $(pwd)/nix/kubeconfig.hetzner.yaml
              '';
              name = "6-move-provisioning-to-cluster-itself";
              category = "setup";
            }
            {
              package = pkgs.writeShellScriptBin "delete-provisioned-cluster" ''
                KUBECONFIG=$(pwd)/kubeconfig kubectl delete cluster my-cluster
              '';
              name = "7-delete-provisioned-cluster";
              category = "setup";
            }
          ];
        };
      };
    };
}
