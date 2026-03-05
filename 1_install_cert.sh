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