class VstsConfig {
    static [String] $Filename = "${env:HOME}\.vsts-util-config.json"
    
    [String] $AccountName
    [String] $Project
    [String] $User
    [String] $Token

    VstsConfig([String] $AccountName, [String] $Project, [String] $User, [String] $Token) {
        $this.AccountName=$AccountName
        $this.Project=$Project
        $this.User=$User
        $this.Token=$Token
    }
    
    static [VstsConfig] load() {
        $configFile = [VstsConfig]::Filename
        if( !(Get-Item $configFile -ErrorAction SilentlyContinue)){
           throw "$configFile not found!  Use Set-VstsConfig" 
        }
        $conf = ConvertFrom-Json (Get-Content -Path $configFile | Out-String)
        
        $secure = ConvertTo-SecureString $conf.token 
        $cred = New-Object System.Management.Automation.PSCredential("test", $secure)
        $plaintext = $cred.GetNetworkCredential().Password

        return [VstsConfig]::new($conf.AccountName, $conf.Project, $conf.User, $plaintext)
    }

    [void] save() {
        $secure = ConvertTo-SecureString $this.Token -Force -AsPlainText
        $standard = ConvertFrom-SecureString $secure
        $output = ConvertTo-Json @{
            AccountName=$this.AccountName
            Project=$this.Project
            User=$this.User
            Token=$standard
        }
        
        Set-Content -Path $this::Filename -Value $output
    } 

    [hashtable] GetHeaders(){
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $this.User, $this.Token)))
        return @{Authorization=("Basic {0}" -f $base64AuthInfo)} 
    } 
}

function Get-VstsConfig {
    [CmdletBinding()]param()
    [VstsConfig]::load() 
}

function Set-VstsConfig {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $AccountName,
        [Parameter(Mandatory=$true)][String] $Project,
        [Parameter(Mandatory=$true)][String] $User,
        [Parameter(Mandatory=$true)][String] $Token
    ) 
    $config = [VstsConfig]::new($AccountName, $Project, $User, $Token)
    $config.save()
}


function Find-ReleaseDefinition {
    [CmdletBinding()]
    Param(
        [Parameter(Position=1)][string]$CLike="*"
    ) 

    $config = Get-VstsConfig
    $uri = "https://$($config.AccountName).vsrm.visualstudio.com/$($config.Project)/_apis/release/definitions?api-version=4.1-preview.3"
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
    
    $result.value | Where-Object -Property name -CLike $CLike
    return $result
}
# 
function New-Release {
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)][int]$definitionId
    )

    $config = Get-VstsConfig
    $uri = "https://$($config.AccountName).vsrm.visualstudio.com/$($config.Project)/_apis/release/releases?api-version=4.1-preview.6"
    $body = ConvertTo-Json @{ definitionId = "$definitionId" }    
    Invoke-RestMethod -Uri $uri -Body $body -Method Post -ContentType "application/json" -Headers $config.GetHeaders()
}

# function Find-BuildDefinition {
#     [CmdletBinding()]
#     Param(
#         [Parameter(Position=1)][string]$CLike="*"
#     ) 
#     $uri = "https://${accountName}.visualstudio.com/${project}/_apis/build/definitions?api-version=4.1"
#     $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)}
#     $result.value | Where-Object -Property name -CLike $CLike
# }
# 
# function New-Build {
#     [CmdletBinding()]
#     Param(
#         [Parameter(Position=1, Mandatory=$true)][string]$definitionId
#     )
# 
#     $uri = "https://${accountName}.visualstudio.com/${project}/_apis/release/releases?api-version=4.1"
#     $body = ConvertTo-Json @{ definitionId = $definitionId }    
#     Invoke-RestMethod -Uri $uri -Body $body -Method Post -ContentType "application/json" -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} 
# }
# 
# function Get-VstsConfig {
#     
# }
# 
# 
# 
# function Set-VstsConfig {
#    [Parameter(Required=$true)][string]$accountName,
#    [Parameter(Required=$true)][string]$project,
#    [Parameter(Required=$true)][string]$user,
#    [Parameter(Required=$true)][string]$token
# 
#     @{ 
#        accountName = $accountName,
#        project=$project,
#        user=$user,
#        token=$token 
#     }
#     ConvertTo-Json
# }
# 
# function Invoke-VstsService {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory=$true)][string]$Uri,
#         [Parameter(Mandatory=$true)][string]$Method 
#     )
# }
# 
# Export-ModuleMember Find-ReleaseDefinition
# Export-ModuleMember New-Release
# 
# Export-ModuleMember Find-BuildDefinition
# Export-ModuleMember New-Build

Export-ModuleMember VstsConfig
Export-ModuleMember Set-VstsConfig
Export-ModuleMember Get-VstsConfig
Export-ModuleMember Find-ReleaseDefinition
Export-ModuleMember New-Release
