# Kubernetes Migration Roadmap

**Purpose**: This document outlines the strategy for migrating the Ping Identity platform from Docker Compose to Kubernetes.

**Status**: Planning Phase
**Target Timeline**: Q2 2025
**Last Updated**: 2025-11-04

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Why Kubernetes?](#why-kubernetes)
3. [Migration Strategy](#migration-strategy)
4. [Architecture in Kubernetes](#architecture-in-kubernetes)
5. [Phase-by-Phase Migration Plan](#phase-by-phase-migration-plan)
6. [Kubernetes Resources Required](#kubernetes-resources-required)
7. [Helm Charts](#helm-charts)
8. [Storage Considerations](#storage-considerations)
9. [Networking in Kubernetes](#networking-in-kubernetes)
10. [Security in Kubernetes](#security-in-kubernetes)
11. [Monitoring and Observability](#monitoring-and-observability)
12. [Testing Strategy](#testing-strategy)
13. [Rollback Plan](#rollback-plan)
14. [Lessons Learned from Docker](#lessons-learned-from-docker)

---

## Executive Summary

This roadmap provides a comprehensive plan to migrate the current Docker Compose-based Ping Identity platform to Kubernetes. The migration will enhance scalability, resilience, and operational efficiency while maintaining zero downtime for production services.

### Key Benefits of K8s Migration

- **Auto-scaling**: Horizontal Pod Autoscaling (HPA) based on CPU/memory
- **Self-healing**: Automatic pod restart and rescheduling on node failures
- **Rolling updates**: Zero-downtime deployments with rollback capability
- **Service discovery**: Built-in DNS and load balancing
- **Resource management**: Better CPU/memory allocation and limits
- **Declarative configuration**: Infrastructure as Code (IaC) with GitOps
- **Multi-node deployment**: True high availability across nodes

### Migration Timeline

| Phase | Description | Duration | Target Date |
|-------|-------------|----------|-------------|
| Phase 0 | Planning & Prerequisites | 2 weeks | Q1 2025 |
| Phase 1 | K8s Cluster Setup | 1 week | Q2 2025 |
| Phase 2 | PingDS Migration | 2 weeks | Q2 2025 |
| Phase 3 | PingIDM Migration | 2 weeks | Q2 2025 |
| Phase 4 | PingAM Migration | 2 weeks | Q2 2025 |
| Phase 5 | Testing & Validation | 2 weeks | Q2 2025 |
| Phase 6 | Production Cutover | 1 week | Q2 2025 |

**Total Estimated Time**: 12 weeks

---

## Why Kubernetes?

### Current Docker Compose Limitations

While Docker Compose works well for development and single-host deployments, it has limitations for production:

**❌ Limited High Availability**:
- Single host failure = complete outage
- No automatic failover between containers
- Manual intervention required for recovery

**❌ No Auto-Scaling**:
- Fixed number of containers
- Manual scaling by editing docker-compose.yml
- Cannot scale based on load

**❌ Limited Resource Management**:
- No resource quotas or limits enforcement
- Risk of resource contention on single host
- Difficult to prioritize workloads

**❌ Manual Updates**:
- Requires downtime for updates
- No built-in rollback mechanism
- High risk of human error

**❌ Single Host Constraint**:
- All containers on one host
- Limited by single host resources
- No geographic distribution

### Kubernetes Advantages

**✅ True High Availability**:
- Multi-node cluster (3+ nodes recommended)
- Automatic pod rescheduling on node failure
- Self-healing containers
- StatefulSets for ordered, predictable deployments

**✅ Auto-Scaling**:
- Horizontal Pod Autoscaler (HPA) for CPU/memory
- Vertical Pod Autoscaler (VPA) for rightsizing
- Cluster Autoscaler for node scaling
- Custom metrics-based scaling (e.g., LDAP query rate)

**✅ Advanced Resource Management**:
- Resource requests and limits per container
- Quality of Service (QoS) classes
- Resource quotas per namespace
- Pod priority and preemption

**✅ Zero-Downtime Deployments**:
- Rolling updates with configurable strategy
- Automatic rollback on failures
- Blue-green and canary deployments
- Readiness/liveness probes

**✅ Multi-Node, Multi-Region**:
- Spread pods across availability zones
- Node affinity and anti-affinity rules
- Geographic distribution for DR
- Cross-region replication

---

## Migration Strategy

### Approach: Lift-and-Shift with Optimization

We'll use a **phased migration** approach:

1. **Containerization** ✅ (Already done with Docker Compose)
2. **Direct Translation** - Convert Docker Compose to K8s manifests
3. **Optimization** - Refactor to leverage K8s features
4. **Enhancement** - Add auto-scaling, monitoring, GitOps

### Migration Principles

1. **Zero Downtime**: Run Docker and K8s in parallel during transition
2. **Gradual Cutover**: Migrate one service at a time (DS → IDM → AM)
3. **Testing First**: Validate in dev/test before production
4. **Rollback Ready**: Maintain Docker deployment as fallback
5. **Data Safety**: Backup all data before migration
6. **Documentation**: Update all docs to reflect K8s deployment

### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Data loss during migration | Take full backups; test restore procedures |
| Service downtime | Parallel run with gradual traffic shift |
| Configuration errors | Use GitOps with peer review; automated validation |
| Performance degradation | Load testing before cutover; monitoring dashboards |
| Team knowledge gap | Training sessions; runbooks; practice migrations |

---

## Architecture in Kubernetes

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│                   (3+ Worker Nodes)                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Namespace: ping-identity                                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                             │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │  │
│  │  │   Ingress   │  │   Ingress   │  │   Ingress   │       │  │
│  │  │  (Nginx)    │  │  (Nginx)    │  │  (Nginx)    │       │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘       │  │
│  │         │                │                │                │  │
│  │         └────────────────┼────────────────┘                │  │
│  │                          │                                  │  │
│  │  ┌───────────────────────▼───────────────────────┐        │  │
│  │  │         PingAM Service (ClusterIP)            │        │  │
│  │  │   ┌────────────┐  ┌────────────┐             │        │  │
│  │  │   │  AM Pod 1  │  │  AM Pod 2  │             │        │  │
│  │  │   │ (Replica)  │  │ (Replica)  │             │        │  │
│  │  │   └────────────┘  └────────────┘             │        │  │
│  │  └───────────────────────┬───────────────────────┘        │  │
│  │                          │                                  │  │
│  │  ┌───────────────────────▼───────────────────────┐        │  │
│  │  │         PingIDM Service (ClusterIP)           │        │  │
│  │  │   ┌────────────┐  ┌────────────┐             │        │  │
│  │  │   │  IDM Pod 1 │  │  IDM Pod 2 │             │        │  │
│  │  │   │ (Replica)  │  │ (Replica)  │             │        │  │
│  │  │   └────────────┘  └────────────┘             │        │  │
│  │  └───────────────────────┬───────────────────────┘        │  │
│  │                          │                                  │  │
│  │  ┌───────────────────────▼───────────────────────────┐    │  │
│  │  │    PingDS StatefulSet (Headless Service)         │    │  │
│  │  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐         │    │  │
│  │  │  │ ds-0 │  │ ds-1 │  │ ds-2 │  │ ds-3 │         │    │  │
│  │  │  │ (Pod)│  │ (Pod)│  │ (Pod)│  │ (Pod)│         │    │  │
│  │  │  └───┬──┘  └───┬──┘  └───┬──┘  └───┬──┘         │    │  │
│  │  │      │         │         │         │              │    │  │
│  │  │  ┌───▼─────────▼─────────▼─────────▼───┐        │    │  │
│  │  │  │   Persistent Volume Claims (PVCs)   │        │    │  │
│  │  │  │        (Storage Class)               │        │    │  │
│  │  │  └──────────────────────────────────────┘        │    │  │
│  │  └────────────────────────────────────────────────────┘    │  │
│  │                                                             │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Kubernetes Resources Mapping

| Docker Compose | Kubernetes Resource | Purpose |
|----------------|---------------------|---------|
| `service` | Pod | Container runtime |
| `networks` | Service (ClusterIP) | Internal networking |
| `ports` | Service (NodePort/LoadBalancer) | External access |
| `volumes` | PersistentVolumeClaim (PVC) | Data persistence |
| `environment` | ConfigMap, Secret | Configuration |
| `depends_on` | InitContainer, Pod affinity | Startup ordering |
| `restart` | Deployment, StatefulSet | Self-healing |
| `healthcheck` | Liveness/Readiness probes | Health monitoring |

---

## Phase-by-Phase Migration Plan

### Phase 0: Planning & Prerequisites (2 weeks)

**Objectives**:
- Set up Kubernetes cluster
- Prepare team with K8s training
- Create development/testing environment

**Tasks**:
- [ ] Choose K8s distribution (Options: managed K8s, kubeadm, k3s, Rancher)
- [ ] Provision K8s cluster (3+ nodes for HA)
- [ ] Install kubectl and helm CLI tools
- [ ] Set up kubectl context and access
- [ ] Install Ingress Controller (Nginx or Traefik)
- [ ] Install cert-manager for TLS certificates
- [ ] Set up storage provisioner (dynamic PV provisioning)
- [ ] Team training on K8s basics
- [ ] Document K8s cluster architecture
- [ ] Create namespace: `kubectl create namespace ping-identity`

**Deliverables**:
- [ ] Kubernetes cluster operational
- [ ] Ingress controller deployed
- [ ] Storage class configured
- [ ] Team trained on K8s fundamentals
- [ ] K8s cluster documentation

---

### Phase 1: K8s Cluster Setup (1 week)

**Objectives**:
- Install and configure all K8s infrastructure components
- Set up monitoring and logging
- Validate cluster health

**Tasks**:

**1.1 Cluster Installation** (Day 1-2):
```bash
# Option 1: Managed Kubernetes (Recommended for production)
# - GKE (Google Kubernetes Engine)
# - EKS (Amazon Elastic Kubernetes Service)
# - AKS (Azure Kubernetes Service)

# Option 2: Self-managed (On-premise)
# Using kubeadm:
kubeadm init --pod-network-cidr=10.244.0.0/16

# Install CNI (Calico or Flannel)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Join worker nodes
kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

**1.2 Install Essential Add-ons** (Day 3):
```bash
# Install Nginx Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Install cert-manager for TLS
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

# Install metrics-server for HPA
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**1.3 Storage Configuration** (Day 4):
```bash
# Create storage class for dynamic provisioning
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs  # Adjust for your provider
parameters:
  type: gp3
  iopsPerGB: "50"
  encrypted: "true"
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
EOF
```

**1.4 Monitoring Setup** (Day 5):
```bash
# Install Prometheus + Grafana (kube-prometheus-stack)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Default: admin/prom-operator
```

**1.5 Logging Setup** (Day 5):
```bash
# Install Loki for log aggregation
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace logging --create-namespace \
  --set promtail.enabled=true
```

**Validation Checklist**:
- [ ] All nodes in Ready state: `kubectl get nodes`
- [ ] All system pods running: `kubectl get pods -A`
- [ ] Ingress controller accessible
- [ ] Metrics server providing data: `kubectl top nodes`
- [ ] Prometheus scraping metrics
- [ ] Grafana dashboards accessible
- [ ] Storage provisioner creating PVs

---

### Phase 2: PingDS Migration (2 weeks)

**Objectives**:
- Deploy PingDS StatefulSet in Kubernetes
- Establish replication between K8s DS and Docker DS
- Validate data consistency
- Cutover to K8s DS

**2.1 Create PingDS StatefulSet** (Week 1):

```yaml
# manifests/pingds-statefulset.yaml
apiVersion: v1
kind: Service
metadata:
  name: pingds-headless
  namespace: ping-identity
spec:
  clusterIP: None
  selector:
    app: pingds
  ports:
    - name: ldaps
      port: 1636
    - name: admin
      port: 4444
    - name: replication
      port: 8989
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: pingds
  namespace: ping-identity
spec:
  serviceName: pingds-headless
  replicas: 4
  selector:
    matchLabels:
      app: pingds
  template:
    metadata:
      labels:
        app: pingds
    spec:
      containers:
      - name: opendj
        image: openjdk:17-slim
        volumeMounts:
        - name: ds-data
          mountPath: /opt/opendj/db
        - name: ds-install
          mountPath: /opt/opendj
          readOnly: true
        ports:
        - containerPort: 1636
          name: ldaps
        - containerPort: 4444
          name: admin
        - containerPort: 8989
          name: replication
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        envFrom:
        - configMapRef:
            name: pingds-config
        - secretRef:
            name: pingds-secrets
        livenessProbe:
          exec:
            command:
            - /opt/opendj/bin/status
            - --bindDN
            - "cn=Directory Manager"
            - --bindPasswordFile
            - /opt/secrets/admin-password
          initialDelaySeconds: 120
          periodSeconds: 30
        readinessProbe:
          tcpSocket:
            port: 1636
          initialDelaySeconds: 60
          periodSeconds: 10
  volumeClaimTemplates:
  - metadata:
      name: ds-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
```

**2.2 Data Migration Strategy**:

**Option A: Replication-Based (Recommended)**:
1. Deploy K8s DS instances (ds-0, ds-1, ds-2, ds-3)
2. Enable replication from Docker DS1 to K8s ds-0
3. Let replication sync all data
4. Gradually shift read traffic to K8s DS
5. After validation, shift write traffic
6. Decommission Docker DS

**Option B: Backup & Restore**:
1. Take backup from Docker DS1
2. Restore to K8s ds-0
3. Initialize other K8s DS replicas from ds-0
4. Validate data integrity
5. Switch DNS/connections to K8s DS

**2.3 Testing Checklist**:
- [ ] All DS pods running and ready
- [ ] Replication functioning between pods
- [ ] LDAP searches working
- [ ] Write operations successful
- [ ] Performance equivalent to Docker deployment
- [ ] Failover testing (delete pod, verify rescheduling)

---

### Phase 3: PingIDM Migration (2 weeks)

**Objectives**:
- Deploy PingIDM as Deployment in K8s
- Configure IDM to use K8s PingDS
- Test connectors and reconciliation
- Cutover to K8s IDM

**3.1 Create PingIDM Deployment**:

```yaml
# manifests/pingidm-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pingidm
  namespace: ping-identity
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pingidm
  template:
    metadata:
      labels:
        app: pingidm
    spec:
      containers:
      - name: openidm
        image: openjdk:17-slim
        volumeMounts:
        - name: idm-conf
          mountPath: /opt/openidm/conf
        - name: idm-connectors
          mountPath: /opt/openidm/connectors
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        env:
        - name: REPO_PRIMARY_HOST
          value: "pingds-0.pingds-headless"
        - name: REPO_SECONDARY_HOST
          value: "pingds-1.pingds-headless"
        envFrom:
        - configMapRef:
            name: pingidm-config
        - secretRef:
            name: pingidm-secrets
        livenessProbe:
          httpGet:
            path: /openidm/info/ping
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 180
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /openidm/info/ping
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 120
          periodSeconds: 10
      volumes:
      - name: idm-conf
        configMap:
          name: pingidm-conf
      - name: idm-connectors
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: pingidm
  namespace: ping-identity
spec:
  selector:
    app: pingidm
  ports:
    - name: https
      port: 8443
      targetPort: 8443
  type: ClusterIP
```

**3.2 ConfigMap for IDM Configuration**:
- Store boot.properties, cluster.json, repo.ds.json in ConfigMaps
- Use Secrets for passwords and sensitive data

**3.3 Testing Checklist**:
- [ ] IDM pods running
- [ ] Admin console accessible via Ingress
- [ ] Cluster formation successful
- [ ] DS repository connection working
- [ ] Connectors operational
- [ ] Reconciliation jobs executing

---

### Phase 4: PingAM Migration (2 weeks)

**Objectives**:
- Deploy PingAM as Deployment in K8s
- Configure AM to use K8s DS for config/identity/CTS
- Test authentication flows
- Cutover to K8s AM

**4.1 Create PingAM Deployment**:

```yaml
# manifests/pingam-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pingam
  namespace: ping-identity
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pingam
  template:
    metadata:
      labels:
        app: pingam
    spec:
      containers:
      - name: tomcat
        image: tomcat:9-jdk17
        volumeMounts:
        - name: am-war
          mountPath: /usr/local/tomcat/webapps/am.war
          subPath: AM-7.5.2.war
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: CATALINA_OPTS
          value: "-Xms4g -Xmx4g"
        - name: CONFIG_STORE_HOST
          value: "pingds-0.pingds-headless"
        envFrom:
        - configMapRef:
            name: pingam-config
        - secretRef:
            name: pingam-secrets
        livenessProbe:
          httpGet:
            path: /am/isAlive.jsp
            port: 8080
          initialDelaySeconds: 240
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /am/isAlive.jsp
            port: 8080
          initialDelaySeconds: 180
          periodSeconds: 10
      volumes:
      - name: am-war
        configMap:
          name: pingam-war
---
apiVersion: v1
kind: Service
metadata:
  name: pingam
  namespace: ping-identity
spec:
  selector:
    app: pingam
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  type: ClusterIP
```

**4.2 Ingress for External Access**:

```yaml
# manifests/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ping-ingress
  namespace: ping-identity
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - sso.example.com
    secretName: pingam-tls
  rules:
  - host: sso.example.com
    http:
      paths:
      - path: /am
        pathType: Prefix
        backend:
          service:
            name: pingam
            port:
              number: 8080
  - host: idm.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pingidm
            port:
              number: 8443
```

**4.3 Testing Checklist**:
- [ ] AM pods running
- [ ] AM console accessible via Ingress
- [ ] DS stores (config/identity/CTS) connected
- [ ] User authentication working
- [ ] Session replication functional
- [ ] OAuth2 token issuance working

---

### Phase 5: Testing & Validation (2 weeks)

**Comprehensive Testing**:

**5.1 Functional Testing**:
- [ ] End-to-end authentication flow
- [ ] IDM reconciliation from all sources
- [ ] AM SSO across applications
- [ ] OAuth2/OIDC token flows
- [ ] SAML federation (if applicable)

**5.2 Performance Testing**:
- [ ] Load test with JMeter (simulate 5k users)
- [ ] Measure LDAP response times
- [ ] Measure authentication latency
- [ ] Stress test DS replication

**5.3 High Availability Testing**:
- [ ] Delete DS pod, verify auto-recovery
- [ ] Delete IDM pod, verify cluster failover
- [ ] Delete AM pod, verify session persistence
- [ ] Drain node, verify pod rescheduling
- [ ] Network partition simulation

**5.4 Disaster Recovery Testing**:
- [ ] Backup DS data from PV
- [ ] Restore DS to new PV
- [ ] Validate data integrity after restore

---

### Phase 6: Production Cutover (1 week)

**Cutover Strategy**: Blue-Green Deployment

**6.1 Preparation** (Day 1-2):
- [ ] Final backup of Docker environment
- [ ] Final sync from Docker to K8s
- [ ] Update DNS TTL to 60 seconds (for quick rollback)
- [ ] Notify stakeholders of cutover window

**6.2 Execution** (Day 3):
- [ ] 00:00 - Maintenance window begins
- [ ] 00:15 - Stop new user creation in Docker IDM
- [ ] 00:30 - Final reconciliation sync
- [ ] 00:45 - Update DNS to point to K8s Ingress
- [ ] 01:00 - Monitor traffic shifting to K8s
- [ ] 02:00 - Validate all services operational
- [ ] 03:00 - Maintenance window ends

**6.3 Post-Cutover Monitoring** (Day 4-7):
- [ ] 24/7 monitoring for first 48 hours
- [ ] Daily health checks for first week
- [ ] Performance baseline comparison
- [ ] User feedback collection

**6.4 Rollback Trigger**:
If any of the following occur, rollback to Docker:
- Critical authentication failures (> 5% failure rate)
- Data corruption detected
- Performance degradation (> 50% slower)
- Unrecoverable service outages

**Rollback Procedure**:
1. Update DNS back to Docker environment (5 min)
2. Restart Docker containers if needed (5 min)
3. Verify services operational (10 min)
4. Root cause analysis (post-mortem)

---

## Kubernetes Resources Required

### Cluster Specifications

**Minimum (Development/Test)**:
- Nodes: 3 worker nodes
- CPU: 8 cores per node (24 total)
- Memory: 16 GB per node (48 GB total)
- Storage: 200 GB per node (600 GB total)

**Recommended (Production)**:
- Nodes: 5-7 worker nodes
- CPU: 16 cores per node
- Memory: 32 GB per node
- Storage: 500 GB SSD per node
- Network: 10 Gbps

### Resource Allocation per Service

| Service | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage |
|---------|----------|-------------|-----------|----------------|--------------|---------|
| PingDS | 4 | 2 cores | 4 cores | 4 GB | 8 GB | 50 GB PV each |
| PingIDM | 2 | 2 cores | 4 cores | 4 GB | 8 GB | 10 GB PV each |
| PingAM | 2 | 2 cores | 4 cores | 4 GB | 8 GB | 10 GB PV each |
| **Total** | **8** | **16 cores** | **32 cores** | **32 GB** | **64 GB** | **240 GB** |

Add 20-30% overhead for K8s system pods, monitoring, and logging.

---

## Helm Charts

Helm simplifies K8s deployments by templating manifests.

### Helm Chart Structure

```
helm/
├── pingds/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── statefulset.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       └── secret.yaml
│
├── pingidm/
│   └── (similar structure)
│
└── pingam/
    └── (similar structure)
```

### Example values.yaml

```yaml
# helm/pingds/values.yaml
replicaCount: 4

image:
  repository: openjdk
  tag: 17-slim
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 2
    memory: 4Gi
  limits:
    cpu: 4
    memory: 8Gi

persistence:
  enabled: true
  storageClass: fast-ssd
  size: 50Gi

config:
  baseDN: dc=example,dc=com
  rootUserDN: cn=Directory Manager

secrets:
  rootUserPassword: ChangeMe123!

service:
  type: ClusterIP
  ports:
    ldaps: 1636
    admin: 4444
    replication: 8989
```

### Helm Deployment Commands

```bash
# Install PingDS
helm install pingds ./helm/pingds \
  -f ./helm/pingds/values-prod.yaml \
  --namespace ping-identity

# Upgrade PingDS
helm upgrade pingds ./helm/pingds \
  -f ./helm/pingds/values-prod.yaml \
  --namespace ping-identity

# Rollback
helm rollback pingds 1 --namespace ping-identity

# Uninstall
helm uninstall pingds --namespace ping-identity
```

---

## Storage Considerations

### Persistent Volume (PV) Strategy

**PingDS** (StatefulSet):
- Requires persistent storage for database files
- Use PersistentVolumeClaims (PVCs) with StatefulSet
- Storage class: SSD with high IOPS
- Reclaim policy: Retain (for data safety)
- Backup strategy: Snapshot PVs regularly

**PingIDM** (Deployment):
- Configuration in ConfigMaps (ephemeral OK)
- Logs can be ephemeral (use log aggregation)
- If using file-based audit logs, use PV

**PingAM** (Deployment):
- Configuration in DS (no local PV needed)
- Logs ephemeral

### Backup Strategy in K8s

```bash
# Install Velero for cluster backups
helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace

# Backup entire namespace
velero backup create ping-identity-backup \
  --include-namespaces ping-identity

# Restore
velero restore create --from-backup ping-identity-backup
```

---

## Networking in Kubernetes

### Service Types

**ClusterIP** (Internal only):
- PingDS, PingIDM, PingAM services
- Only accessible within cluster

**NodePort** (External access on node):
- Not recommended for production
- Use for testing if Ingress not available

**LoadBalancer** (Cloud LB):
- Use for external access if no Ingress
- Cloud provider provisions external LB

**Ingress** (Recommended):
- HTTP/HTTPS routing
- TLS termination
- Path-based routing
- Host-based routing

### Network Policies

Restrict traffic between pods for security:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pingds-allow-idm-am
  namespace: ping-identity
spec:
  podSelector:
    matchLabels:
      app: pingds
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: pingidm
    - podSelector:
        matchLabels:
          app: pingam
    ports:
    - protocol: TCP
      port: 1636
    - protocol: TCP
      port: 8989
```

---

## Security in Kubernetes

### Secrets Management

**Option 1: Kubernetes Secrets** (Basic):
```bash
kubectl create secret generic pingds-secrets \
  --from-literal=rootPassword=ChangeMe123! \
  --namespace ping-identity
```

**Option 2: External Secrets Operator** (Recommended):
- Integrate with HashiCorp Vault, AWS Secrets Manager, Azure Key Vault
- Automatic secret rotation
- Audit logging

### RBAC (Role-Based Access Control)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ping-operator
  namespace: ping-identity
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "statefulsets", "services"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ping-operator-binding
  namespace: ping-identity
subjects:
- kind: ServiceAccount
  name: ping-operator
  namespace: ping-identity
roleRef:
  kind: Role
  name: ping-operator
  apiGroup: rbac.authorization.k8s.io
```

### Pod Security Policies

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: ping-psp
spec:
  privileged: false
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
  - configMap
  - secret
  - persistentVolumeClaim
```

---

## Monitoring and Observability

### Prometheus Metrics

Expose metrics from Ping services:

```yaml
# PingDS metrics endpoint
apiVersion: v1
kind: Service
metadata:
  name: pingds-metrics
  namespace: ping-identity
  labels:
    app: pingds
spec:
  selector:
    app: pingds
  ports:
  - name: metrics
    port: 9090
    targetPort: 9090
```

### Grafana Dashboards

Create dashboards for:
- LDAP operations per second
- Replication lag
- Authentication success/failure rates
- Resource utilization (CPU, memory, disk)
- Pod health status

### Alerts

Configure Prometheus alerting rules:

```yaml
groups:
- name: ping-identity
  rules:
  - alert: DSReplicationLag
    expr: ds_replication_lag_seconds > 10
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "DS replication lag high"
      description: "Replication lag is {{ $value }} seconds"

  - alert: IDMSyncFailure
    expr: idm_sync_failures_total > 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "IDM sync job failed"

  - alert: AMAuthFailureRate
    expr: rate(am_auth_failures[5m]) > 0.05
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High authentication failure rate"
```

---

## Testing Strategy

### Pre-Migration Testing

1. **Unit Tests**: Test individual K8s manifests with kubeval
2. **Integration Tests**: Deploy to dev K8s cluster
3. **Load Tests**: Simulate production load with JMeter/Gatling
4. **Chaos Tests**: Use Chaos Mesh to simulate failures

### Validation Criteria

Before cutover, ensure:
- [ ] All pods healthy and ready
- [ ] Zero errors in logs for 24 hours
- [ ] Performance matches or exceeds Docker baseline
- [ ] Failover tests successful
- [ ] Backup and restore tested
- [ ] Monitoring and alerting functional
- [ ] Runbooks updated and tested
- [ ] Team trained on K8s operations

---

## Rollback Plan

### Rollback Scenarios

**Scenario 1: Immediate Rollback** (< 1 hour into cutover):
- Update DNS back to Docker
- Docker environment still running

**Scenario 2: Delayed Rollback** (> 1 hour):
- Restore Docker DS from backup
- Restart Docker services
- Update DNS

**Scenario 3: Partial Rollback**:
- Roll back one service at a time
- E.g., roll back AM to Docker, keep DS/IDM in K8s

### Rollback Testing

Practice rollback procedures monthly:
- [ ] Simulate cutover to K8s
- [ ] Trigger rollback condition
- [ ] Execute rollback to Docker
- [ ] Measure RTO (Recovery Time Objective)
- [ ] Document lessons learned

---

## Lessons Learned from Docker

### What Worked Well

✅ **Container Images**: Reuse Docker images in K8s with minimal changes
✅ **Volume Mounts**: Similar concept (Docker volumes → PVCs)
✅ **Environment Variables**: ConfigMaps/Secrets work similarly
✅ **Networking**: Service discovery easier in K8s

### Challenges to Address

⚠️ **Startup Ordering**: Docker `depends_on` not available; use InitContainers
⚠️ **Health Checks**: K8s probes are stricter; tune delays and timeouts
⚠️ **State Management**: StatefulSets require careful planning
⚠️ **Configuration**: ConfigMaps have size limits (1 MB); split large configs

### Improvements in K8s

🚀 **Auto-Scaling**: HPA enables automatic scaling based on metrics
🚀 **Self-Healing**: Pods restart automatically on failure
🚀 **Rolling Updates**: Zero-downtime deployments
🚀 **Observability**: Built-in integration with Prometheus/Grafana
🚀 **Security**: RBAC, network policies, pod security policies

---

## Next Steps

### Immediate Actions

1. **Review this roadmap** with the team
2. **Choose Kubernetes distribution** (managed vs. self-hosted)
3. **Set up dev/test K8s cluster** for experimentation
4. **Begin Phase 0**: Planning & Prerequisites
5. **Schedule team training** on Kubernetes fundamentals

### Resources

**Kubernetes Documentation**:
- Official K8s Docs: https://kubernetes.io/docs/
- Kubernetes Patterns: https://k8spatterns.io/
- Helm Documentation: https://helm.sh/docs/

**Training**:
- Kubernetes Basics (CNCF)
- Certified Kubernetes Administrator (CKA)
- Kubernetes for Developers (CKAD)

**Tools**:
- kubectl: K8s CLI
- Helm: Package manager for K8s
- k9s: Terminal UI for K8s
- Lens: Desktop GUI for K8s

---

## Conclusion

Migrating to Kubernetes will significantly enhance the Ping Identity platform's resilience, scalability, and operational efficiency. This roadmap provides a structured approach to achieve a successful migration with minimal risk.

**Key Success Factors**:
- Thorough planning and testing
- Gradual, phased approach
- Team training and knowledge transfer
- Comprehensive monitoring and alerting
- Documented rollback procedures

**Timeline**: 12 weeks from planning to production cutover

**Next Review**: After Phase 0 completion, reassess timeline and adjust as needed

---

**Document Version**: 1.0
**Last Updated**: 2025-11-04
**Author**: IAM Engineering Team
**Review Schedule**: Monthly during migration, quarterly post-migration

---

*End of Kubernetes Migration Roadmap*
