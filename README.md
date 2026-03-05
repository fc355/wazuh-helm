# 🛡️ Wazuh on Kubernetes via Helm

คู่มือการติดตั้ง Wazuh บน Kubernetes โดยใช้ Helm Chart แบบ Step-by-Step

---

## 📋 Prerequisites

| รายการ | เวอร์ชันแนะนำ |
|---|---|
| Kubernetes cluster | v1.24+ |
| Helm | v3.x |
| kubectl | ตรงกับ cluster version |
| Storage Provisioner | เช่น local-path, Longhorn, EBS |

---

## 📁 โครงสร้างไฟล์

```
.
├── README.md
├── 1_install_cert.sh        # ติดตั้ง cert-manager
├── 2_addrepo_wazuh-helm.sh  # เพิ่ม Helm repo และเตรียม values
├── 3_install_wazuh.sh       # ติดตั้ง Wazuh
└── my-values.yaml           # Config ที่แก้ไขแล้ว (สร้างในขั้นตอนที่ 2)
```

---

## 🚀 ขั้นตอนการติดตั้ง

### ขั้นตอนที่ 1 — ติดตั้ง cert-manager

**ไฟล์:** `1_install_cert.sh`

cert-manager ใช้สำหรับจัดการ TLS certificates อัตโนมัติภายใน cluster

```bash
# เพิ่ม Helm repo ของ cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

# ติดตั้ง cert-manager พร้อม CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# ตรวจสอบว่า pod ทุกตัวขึ้นเป็น Running
kubectl get pods -n cert-manager
```

**ผลลัพธ์ที่ควรเห็น:**
```
NAME                                      READY   STATUS    
cert-manager-xxx                          1/1     Running   
cert-manager-cainjector-xxx               1/1     Running   
cert-manager-webhook-xxx                  1/1     Running   
```

> ⏳ รอให้ทุก pod เป็น `Running` ก่อนไปขั้นตอนถัดไป

---

### ขั้นตอนที่ 2 — เพิ่ม Wazuh Helm Repo และเตรียม Config

**ไฟล์:** `2_addrepo_wazuh-helm.sh`

```bash
# เพิ่ม Wazuh Helm repository
helm repo add wazuh-helm https://promptlylabs.github.io/wazuh-helm-chart/
helm repo update

# สร้าง namespace สำหรับ Wazuh
kubectl create namespace wazuh

# ดึง default values.yaml มาแก้ไข
helm show values wazuh-helm/wazuh > my-values.yaml
```

#### แก้ไขไฟล์ `my-values.yaml`

เปิดไฟล์ `my-values.yaml` แล้วแก้ไขค่าสำคัญดังนี้:

**1. เปลี่ยน Version**
```yaml
# หา field ที่ระบุ image tag และเปลี่ยนเป็น version ที่ต้องการ
indexer:
  image:
    tag: "4.14.1"   # ← เปลี่ยน version ตรงนี้

wazuh:
  image:
    tag: "4.14.1"   # ← เปลี่ยน version ตรงนี้

dashboard:
  image:
    tag: "4.14.1"   # ← เปลี่ยน version ตรงนี้
```

**2. เปลี่ยน Default Storage**
```yaml
# เปลี่ยน storageClass ให้ตรงกับ cluster ของคุณ
indexer:
  storage:
    size: 50Gi
    storageClass: "local-path"   # ← เปลี่ยนตาม StorageClass ของ cluster
                                  #    เช่น local-path, longhorn, standard, gp2

wazuh:
  master:
    storage:
      size: 10Gi
      storageClass: "local-path"  # ← เปลี่ยนให้ตรงกัน

  worker:
    storage:
      size: 10Gi
      storageClass: "local-path"  # ← เปลี่ยนให้ตรงกัน
```

> 💡 ตรวจสอบ StorageClass ที่มีใน cluster ด้วยคำสั่ง `kubectl get storageclass`

---

### ขั้นตอนที่ 3 — ติดตั้ง Wazuh

**ไฟล์:** `3_install_wazuh.sh`

```bash
helm install wazuh wazuh-helm/wazuh \
  --namespace wazuh \
  --values my-values.yaml \
  --timeout 10m \
  --wait
```

ติดตาม progress ในอีก terminal:
```bash
watch kubectl get pods -n wazuh
```

**ผลลัพธ์ที่ควรเห็น:**
```
NAME                          READY   STATUS    
wazuh-indexer-0               1/1     Running   
wazuh-manager-master-0        1/1     Running   
wazuh-manager-worker-0        1/1     Running   
wazuh-dashboard-xxx           1/1     Running   
```

---

## 🌐 เข้าใช้งาน Wazuh Dashboard

### Port-forward (สำหรับทดสอบ)
```bash
kubectl port-forward svc/wazuh-dashboard 5601:443 -n wazuh
```
เปิด browser: **https://localhost:5601**

| | |
|---|---|
| **Username** | `admin` |
| **Password** | ค่าที่ตั้งใน `my-values.yaml` |

---

## 🔧 คำสั่งที่ใช้บ่อย

```bash
# ดูสถานะ pod ทั้งหมด
kubectl get pods -n wazuh

# ดู log ของ indexer
kubectl logs wazuh-indexer-0 -n wazuh

# ดู events ใน namespace
kubectl get events -n wazuh --sort-by='.lastTimestamp'

# Upgrade หลังแก้ values
helm upgrade wazuh wazuh-helm/wazuh \
  --namespace wazuh \
  --values my-values.yaml
```

---

## 🗑️ ถอนการติดตั้ง

```bash
# ลบ Helm release
helm uninstall wazuh -n wazuh

# ลบ namespace ทั้งหมด
kubectl delete namespace wazuh --force --grace-period=0

# ลบ PV ที่ค้างอยู่ (ถ้ามี)
kubectl get pv | grep wazuh
kubectl delete pv <PV_NAME> --force --grace-period=0
```

---

### แก้ vm.max_map_count 
```bash
sudo sysctl -w vm.max_map_count=262144
```
---

## 📚 References

- [Wazuh Official Documentation](https://documentation.wazuh.com/current/deployment-options/deploying-with-kubernetes/kubernetes-deployment.html)
- [Wazuh Helm Chart Repository](https://promptlylabs.github.io/wazuh-helm-chart/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
