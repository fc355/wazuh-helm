# เพิ่ม Wazuh Helm repository
helm repo add wazuh-helm https://promptlylabs.github.io/wazuh-helm-chart/
helm repo update

# สร้าง namespace สำหรับ Wazuh
kubectl create namespace wazuh

# ดึง default values.yaml มาแก้ไข
helm show values wazuh-helm/wazuh > my-values.yaml