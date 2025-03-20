# To-Do List

## Project Overview
Berno wants to create a simple, cloud-native operations repository that includes:
1. Bootstrap templates for 4 cloud providers (starting with AWS/GCP).
2. Use of kind and `clusterctl` for cluster management.
3. Integration of Nix for custom Helm management.
4. Deployment of a Cardano relay node with Tailscale and configuration updates for access to a block producer.

---

## To-Do List

### 1. Bootstrap Cloud Providers
**Task**: Create a template for bootstrapping Kubernetes clusters on AWS and GCP.  
**Steps**:
1. Use `clusterctl` to initialize and manage clusters.
2. Ensure the template is modular for easy extension to other cloud providers (Azure, etc.).
3. Include infrastructure definitions for storage, networking, and compute resources.

---

### 2. Integrate Nix for Helm Management
**Task**: Set up Nix to manage custom Helm charts.  
**Steps**:
1. Create a Nix configuration file (`default.nix`) to define Helm dependencies.
2. Use `nix-toolbox` to automate Helm chart deployment.
3. Ensure Helm charts are versioned and reproducible.

---

### 3. Deploy Cardano Relay Node
**Task**: Deploy a Cardano relay node with Tailscale and access to a block producer.  
**Steps**:
1. Create a Helm chart for the Cardano relay node.
2. Configure Tailscale for secure networking.
3. Update the node configuration to allow access to the block producer.
4. Use persistent storage (e.g., EBS on AWS or Persistent Disks on GCP) for node data.

---

### 4. Set Up Monitoring and Logging
**Task**: Deploy Grafana and Prometheus for monitoring.  
**Steps**:
1. Create Helm charts for Grafana and Prometheus.
2. Configure Prometheus to scrape metrics from the Cardano node.
3. Set up Grafana dashboards for visualization.

---

### 5. Implement Network Security
**Task**: Lock down traffic to admin origin IPs and node ports.  
**Steps**:
1. Use Kubernetes `NetworkPolicy` to restrict traffic.
2. Configure ingress rules to expose only necessary endpoints.
3. Optionally, implement IP tables for additional host-level security.

---

### 6. Validate and Test
**Task**: Ensure the setup works as expected.  
**Steps**:
1. Test cluster creation on AWS and GCP.
2. Verify the Cardano relay node is operational.
3. Confirm monitoring and logging are functional.
4. Test network security policies.

---

### 7. Document the Setup
**Task**: Provide clear documentation for the repository.  
**Steps**:
1. Write a README with setup instructions.
2. Include examples for extending the template to other cloud providers.
3. Document Helm chart configurations and Nix setup.

---

## Deliverables
1. Modular bootstrap templates for AWS and GCP.
2. Nix configuration for Helm management.
3. Helm chart for the Cardano relay node with Tailscale integration.
4. Monitoring and logging setup with Grafana and Prometheus.
5. Network security policies and documentation.
6. Comprehensive README and usage instructions.

---

## Timeline
- **Week 1**: Bootstrap templates and Nix integration.
- **Week 2**: Cardano relay node deployment and monitoring setup.
- **Week 3**: Network security and testing.
- **Week 4**: Documentation and final validation.

---
