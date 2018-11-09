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

function Get-WorkItem {
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)][int]$id,
	[string[]]$fields,
	[string[]]$expand # None, Relations, Fields, Links, All

    )
    $config = Get-VstsConfig
    $uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/_apis/wit/workitems/${id}?api-version=4.1"

    if( $fields ){
	$uri += "&fields=$fields"
    }

   if( $expand ){
	# this needs a literal $ in the variable name!
	$uri += "&`$expand=$expand"
   }

    write-verbose $uri
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
    return $result
}

function Get-WorkItemFields {
    [CmdletBinding()]
	$config = Get-VstsConfig

	$uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/_apis/wit/fields?api-version=4.1"
	Invoke-RestMethod -Uri $uri -Method Get -Headers $config.GetHeaders() -Verbose:$VerbosePreference 
}

<#
.SYNOPSIS
Gets all the user accounts in the organization (previously called an "account" in VSTS)

.NOTES
This function hasn't been tested when a continuation token is required

.PARAMETER subjectTypes
list of user subject subtypes to reduce the retrieved results, e.g. msa’, ‘aad’, ‘svc’ (service identity), ‘imp’ (imported identity), etc.

.EXAMPLE
PS1>  Find-AzureDevOpsUsers
subjectKind   : user
metaType      : member
domain        : 043207df-e689-4bf6-9020-01038f11f0b1
principalName : tom.mclaughlin@Nebraska.gov
mailAddress   : tom.mclaughlin@Nebraska.gov
origin        : aad
originId      : 27da2ad9-ee76-48cd-98b8-2df94e7f998a
displayName   : McLaughlin, Tom
_links        : @{self=; memberships=; membershipState=; storageKey=; avatar=}
url           : https://vssps.dev.azure.com/tommclaughlin/_apis/Graph/Users/aad.ZDZmNGY4MjAtZDk0Zi03ZjJiLWE1ZjQtMDBkY2IzYzMwOTk4
descriptor    : aad.ZDZmNGY4MjAtZDk0Zi03ZjJiLWE1ZjQtMDBkY2IzYzMwOTk4

subjectKind   : user
domain        : AgentPool
principalName : b2dcf18c-8d98-4339-96fe-4dc6581a93de
mailAddress   :
origin        : vsts
originId      : b74eda1e-0e2c-4fc1-a554-23f0f3f0b1ff
displayName   : Agent Pool Service (3)
_links        : @{self=; memberships=; membershipState=; storageKey=; avatar=}
url           : https://vssps.dev.azure.com/tommclaughlin/_apis/Graph/Users/svc.NjM2YjQ3ODQtYzJjYi00MzA5LTk4YmMtN2ZhOGU1NTliNzQ4OkFnZW50UG9vbDpiMmRjZjE4Yy04ZDk4LTQzMzktOTZmZS00ZGM2NTgxYTkzZGU
descriptor    : svc.NjM2YjQ3ODQtYzJjYi00MzA5LTk4YmMtN2ZhOGU1NTliNzQ4OkFnZW50UG9vbDpiMmRjZjE4Yy04ZDk4LTQzMzktOTZmZS00ZGM2NTgxYTkzZGU

.EXAMPLE
# only get azure active directory users (ignore the service accounts for stuff like pools, builds, etc)
PS1> Find-AzureDevOpsUsers -subjectTypes aad

.EXAMPLE
# search for AAD users by email address 
$users=Get-AllAzureDevOpsUsers -Verbose -subjectTypes aad
$users | where-object -Property mailAddress -like 'tom.mclaughlin@nebraska.gov'

subjectKind   : user
metaType      : member
domain        : 043207df-e689-4bf6-9020-01038f11f0b1
principalName : tom.mclaughlin@Nebraska.gov
mailAddress   : tom.mclaughlin@Nebraska.gov
origin        : aad
originId      : 27da2ad9-ee76-48cd-98b8-2df94e7f998a
displayName   : McLaughlin, Tom
_links        : @{self=; memberships=; membershipState=; storageKey=; avatar=}
url           : https://vssps.dev.azure.com/tommclaughlin/_apis/Graph/Users/aad.ZDZmNGY4MjAtZDk0Zi03ZjJiLWE1ZjQtMDBkY2IzYzMwOTk4
descriptor    : aad.ZDZmNGY4MjAtZDk0Zi03ZjJiLWE1ZjQtMDBkY2IzYzMwOTk4
#>
function Get-AllAzureDevOpsUsers {
    [CmdletBinding()]
	Param(
		[string[]]$subjectTypes
	)
	$config = Get-VstsConfig
	$baseuri= "https://vssps.dev.azure.com/$($config.AccountName)/_apis/graph/users?api-version=4.1-preview.1"

	$body=ConvertTo-Json $lookup
	write-verbose $body
	
	$all = New-Object System.Collections.Generic.List[System.Object] 
#	$val=Invoke-RestMethod -Uri $uri -Method Get -Headers $config.GetHeaders() -ResponseHeadersVariable ResponseHeaders -Verbose:$VerbosePreference -Debug
	do {
		if($continuationToken){
			$uri="$baseuri&continuationToken=$continuationToken"
		} else {
			$uri=$baseuri
		}

		if($subjectTypes){
			$uri += "&subjectTypes=" + ($subjectTypes -join ',')
		}

		$result=Invoke-WebRequest -Uri $uri -Headers $config.GetHeaders() -Verbose:$VerbosePreference
		$content = ConvertFrom-Json $result.Content
		if($content.count -gt 0){
			$all.add($content.value)
		}
		$continuationToken = $result.headers['X-MS-ContinuationToken']
	} while($continuationToken)

	return $all
}

<#
.SYNOPSIS
Creates a new Work Item

.PARAMETER type
The type of work item, e.g. User Story, Bug, Task

.PARAMETER fields
A map of fields, e.g.
@{ 
	"System.Title"="my task"
	"System.Description"="my description"
	"System.AssignedTo"="tom.mclaughlin@nebraska.gov" 
}

.PARAMETER validateOnly
Indicate if you only want to validate the changes without saving the work item

.PARAMETER suppressNotifications
Do not fire any notifications for this change

#>
function New-WorkItem {
    [CmdletBinding()]
    Param(
		[string]$type="Task",
		[Parameter(Mandatory=$true,Position=0)]$fields,
		[switch]$validateOnly=$false,
		[switch]$suppressNotifications=$false

    )
    $config = Get-VstsConfig
	# we really do need the literal `$` in the url on the type! 
	$uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/_apis/wit/workitems/`$$($type)?api-version=4.1"
	if($validateOnly){
		$uri += "&validateOnly=true"
	}

	if($suppressNotifications){
		$uri += "&suppressNotifications=true"
	}

	write-verbose $uri
	$patches = New-Object System.Collections.Generic.List[System.Object] 
	foreach($e in $fields.GetEnumerator()){
		$patches.Add(@{
			op="add"
			path="/fields/$($e.Name)"
			from=$null
			value=$e.Value
		})
	}

	$body=ConvertTo-Json $patches
	write-verbose $body
	Invoke-RestMethod -Uri $uri -Body $body -Method Post -ContentType "application/json-patch+json" -Headers $config.GetHeaders() -Verbose:$VerbosePreference -Debug
}

Export-ModuleMember VstsConfig
Export-ModuleMember Set-VstsConfig
Export-ModuleMember Get-VstsConfig
Export-ModuleMember Find-ReleaseDefinition
Export-ModuleMember New-Release
Export-ModuleMember Get-WorkItem
Export-ModuleMember Get-WorkItemFields
Export-ModuleMember New-WorkItem
Export-ModuleMember Get-AllAzureDevOpsUsers 
