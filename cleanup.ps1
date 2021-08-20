[CmdletBinding(ConfirmImpact = 'High',SupportsShouldProcess)]
param (
    [Parameter()]
    $Region
)
if ( !$Region ) { 
    $Regions = ( Get-AWSRegion | 
        Where-Object { $_.region -match "(us|eu|ca)-(east|west|south|north)"} |
            ForEach-Object {
                try {
                    Get-EC2AvailabilityZone -Region $_.Region | Out-Null
                    $_ 
                }
                catch {
                    
                }
            }).Region
} else { $Regions = $Region }

foreach ($Region in $Regions) {
    $Stacks = Get-CFNStack -Region $Region | Where-Object { $_.StackName -notmatch "^rs-auto-.+" }
    foreach ($stack in $Stacks) {
        if ($PSCmdlet.ShouldProcess($stack.StackName, "Delete Stack")) {
            #buckets will cause the stack delete to fail so we preemptively delete the bucket before the stack delete call
            $buckets = Get-CFNStackResourceList -StackName $stack.StackName -Region $Region | Where-Object { $_.ResourceType -eq 'AWS::S3::Bucket' }
            if ( $buckets ) {
                foreach ($bucket in $buckets) {
                    Remove-S3Bucket -BucketName $bucket.PhysicalResourceId -DeleteBucketContent
                }
            }

            $stack | Remove-CFNStack -Region $Region -Force
        } else {
            Write-Host -ForegroundColor Green ( 'Skipping Stack: {0}' -f $stack.StackName)
            $stack
        }
    }
}