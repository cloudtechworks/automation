# Can be executed as bash/cmd or powershell script
namespace="replaceme-namespace"
configmap="replaceme-configmap"
# For powershell instead:
# namespace="replaceme-namespace"
# configmap="replaceme-configmap"
kubectl delete configmap $configmap -n $namespace