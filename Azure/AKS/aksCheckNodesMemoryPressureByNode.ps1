podData = kubectl top pod --all-namespaces --no-headers | ForEach-Object {
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
 
# Get all valid nodes (only those starting with "aks-")
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
 
# Aggregate memory usage per node
$grouped = $podData | Group-Object -Property { $podToNode["$($_.Namespace)/$($_.PodName)"] } | ForEach-Object {
    $node = $_.Name
    if ($validNodes -contains $node) {  # Only include nodes starting with "aks-"
        $totalMemory = ($_.Group | Measure-Object -Property Memory -Sum).Sum
        $namespaces = $_.Group | Select-Object -ExpandProperty Namespace | Select-Object -Unique
        $nodePool = $nodeToPool[$node]
 
        [PSCustomObject]@{
            Node        = $node
            NodePool    = $nodePool
            TotalMemory = "$totalMemory Mi"
            Namespaces  = ($namespaces -join ", ")
        }
    }
}
 
# Display results in a table
$grouped | Where-Object { $_ -ne $null } | Format-Table -AutoSize