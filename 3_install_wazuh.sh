helm install wazuh wazuh-helm/wazuh \
  --namespace wazuh \
  --values my-values.yaml \
  --timeout 10m \
  --wait