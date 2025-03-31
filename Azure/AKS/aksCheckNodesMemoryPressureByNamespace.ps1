# Get all pod memory usage with node mapping in one go
$podData = kubectl top pod --all-namespaces --no-headers | ForEach-Object {
    $fields = ($_ -split "\s+")
    [PSCustomObject]@{
        Namespace = $fields[0]
        PodName   = $fields[1]
        Memory    = [int]($fields[3] -replace "Mi","")
    }
}
 
# Get all pods with their assigned nodes
$podToNode = @{}
kubectl get pods -o wide --all-namespaces --no-headers | ForEach-Object {
    $fields = ($_ -split "\s+")
    $podToNode["$($fields[0])/$($fields[1])"] = $fields[7]  # Namespace/PodName -> Node
}
 
# Get valid AKS nodes (only nodes that start with "aks-")
$validNodes = kubectl get nodes --no-headers | ForEach-Object { ($_ -split "\s+")[0] } | Where-Object { $_ -match "^aks-" }
 
# Get node-to-nodepool mapping
$nodeToPool = @{}
kubectl get nodes --show-labels --no-headers | ForEach-Object {
    $fields = ($_ -split "\s+")
    $node = $fields[0]
    $labels = $fields[-1]
    if ($labels -match "agentpool=([^,]+)") {
        $nodeToPool[$node] = $matches[1]
    }
}
 
# Aggregate memory usage per namespace (only considering valid AKS nodes)
$grouped = $podData | Where-Object { 
    $podToNode["$($_.Namespace)/$($_.PodName)"] -in $validNodes 
} | Group-Object -Property Namespace | ForEach-Object {
    $namespace = $_.Name
    $totalMemory = ($_.Group | Measure-Object -Property Memory -Sum).Sum
    $nodes = $_.Group | ForEach-Object { $podToNode["$($_.Namespace)/$($_.PodName)"] } | Select-Object -Unique
    $nodePools = $nodes | ForEach-Object { $nodeToPool[$_] } | Select-Object -Unique
    [PSCustomObject]@{
        Namespace    = $namespace
        TotalMemory  = "$totalMemory Mi"
        Nodes        = ($nodes -join ", ") 
        NodePools    = ($nodePools -join ", ") 
    }
}
 
# Display results in a table
$grouped | Format-Table -AutoSize