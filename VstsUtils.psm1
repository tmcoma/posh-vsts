class VstsConfig {
    static [String] $Filename = "${HOME}\.vsts-util-config.json"
    
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


<#
.SYNOPSIS
Pulls all the release definitions for a project and filters on the client side by name

.PARAMETER CLike
"where-object" clause

.PARAMETER Project
Project to use.  If left blank, defaults to what is in the config.

.EXAMPLE
Find-ReleaseDefinition -CLike '*' -Project rev-bit

#>
function Find-ReleaseDefinition {
    [CmdletBinding()]
    Param(
        [Parameter(Position=1)][string]$CLike="*",
		[string]$Project
    ) 

    $config = Get-VstsConfig
	if([string]::isNullOrEmpty($Project)){
		$Project=$config.project
	}

    $uri = "https://$($config.AccountName).vsrm.visualstudio.com/$Project/_apis/release/definitions?api-version=4.1-preview.3"
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
    
    $result.value | Where-Object -Property name -CLike $CLike
    return $result
}

<#
.SYNOPSIS
Gets a release definition by its numeric id.

.PARAMETER Id
The numeric id  of the release, at is it appears in its web url.

.PARAMETER Project
The project to query.  If not specified, uses the one in the config.

.EXAMPLE
Get-ReleaseDefinition 1 -Project rev-bit 3

.EXAMPLE
(Get-ReleaseDefinition -Project rev-bit 3).environments | ConvertTo-Json

#>
function Get-ReleaseDefinition {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=1)][int]$Id,
		[string]$Project
    ) 

    $config = Get-VstsConfig
	if([string]::isNullOrEmpty($Project)){
		$Project=$config.project
	}

	$uri = "https://vsrm.dev.azure.com/$($config.AccountName)/$Project/_apis/release/definitions/$($Id)?api-version=5.0-preview.3"
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
    
    return $result
}


<#
.SYNOPSIS
Pulls all the projects using the currently configured organization.

.PARAMETER CLike
An optional filter (by name), e.g. '*rev*'

.EXAMPLE
Find-Project 'rev-*'


#>
function Find-Project {
    [CmdletBinding()]
    Param(
        [Parameter(Position=1)][string]$CLike="*"
    ) 

    $config = Get-VstsConfig
    $uri = "https://dev.azure.com/$($config.AccountName)/_apis/projects?api-version=5.0-preview.3"
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
    
    $result.value | Where-Object -Property name -CLike $CLike
    return $result
}


function Get-ServiceEndpoint {
    [CmdletBinding()]
    Param(
		[Parameter(Mandatory=$true, position=1)][string]$EndpointId,
		[string]$Project,
		[string]$Org
    ) 
    $config = Get-VstsConfig
	
	if( [string]::isNullOrWhitespace($Org) ){
		$Org = $config.AccountName
	}

	if( [string]::isNullOrWhitespace($Project) ){
		$Project = $config.Project
	}

	write-output "endpointid is $endpointid"
    $uri = "https://dev.azure.com/$Org/$Project/_apis/serviceendpoint/endpoints/$($EndpointId)?api-version=5.0-preview.2"
	write-output $uri
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
    
    return $result
}

function Find-ServiceEndpoint {
    [CmdletBinding()]
    Param(
		[string]$Project,
		[string]$Org
    ) 
    $config = Get-VstsConfig
	
	if( [string]::isNullOrWhitespace($Org) ){
		$Org = $config.AccountName
	}

	if( [string]::isNullOrWhitespace($Project) ){
		$Project = $config.Project
	}

    $uri = "https://dev.azure.com/$Org/$Project/_apis/serviceendpoint/endpoints?api-version=5.0-preview.2"
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
    
    return $result
}
 
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
Returns the list of work item types.


.EXAMPLE
Set-VstsConfig
Get-WorkItemTypes

.EXAMPLE
# deal with max length on convertfrom-json
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")        
$jsonserial= New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
$jsonserial.MaxJsonLength  = 67108864
$WorkItemTypes = Get-WorkItemTypes
$types=$jsonserial.DeserializeObject($WorkItemTypes)

# print work item display name and system name
$types.value | % { write-output "$($_.name)=$($_.referenceName)"  }

.NOTES
That the result may be large enough That ConvertFrom-Json will fail to handle it.
#>
function Get-WorkItemTypes {
    [CmdletBinding()]
	$config = Get-VstsConfig

	$uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/_apis/wit/workitemtypes?api-version=4.1"
    Invoke-RestMethod -Uri $uri -Method Get -Headers $config.GetHeaders() -Verbose:$VerbosePreference 
}

<#
.SYNOPSIS
Gets all the user accounts in the organization (previously called an "account" in VSTS)

.NOTES
This function hasn't been tested when a continuation token is required

.PARAMETER subjectTypes
list of user subject subtypes to reduce the retrieved results, e.g. msa, aad, svc (service identity), imp (imported identity), etc.

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

.PARAMETER bypassRules
Do not enforce the work item type rules on this update


#>
function New-WorkItem {
    [CmdletBinding()]
    Param(
		[string]$type="Task",
		[Parameter(Mandatory=$true,Position=0)]$fields,
		[switch]$validateOnly=$false,
		[switch]$bypassRules=$false,
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

	if($bypassRules){
		$uri += "&bypassRules=true"
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
<#
.SYNOPSIS
Get the list of boards for the current project

.PARAMETER team
The team whose boards are to be retrieved.  If not specified, the default team's board will be retrieved.

.EXAMPLE
# get the list of boards (name only)
(Get-KanbanBoards "Access Manager Forms").value.name
Stories
Epics
Features

.EXAMPLE
# get the boards and their reference urls
(Get-KanbanBoards).value | ConvertTo-Json
[
    {
        "id":  "b86958a4-9b78-46b2-869f-b4b6384ef293",
        "url":  "https://dev.azure.com/tommclaughlin/dc5329bd-bc74-48bb-af94-500843428988/09651aab-8486-42ec-a07e-8c94ea6f3709/_apis/work/boards/b86958a4-9b78-46b2-869f-b4b6384ef293",
        "name":  "Stories"
    },
    {
        "id":  "b31d634b-b573-4393-bfeb-5af850b9dbab",
        "url":  "https://dev.azure.com/tommclaughlin/dc5329bd-bc74-48bb-af94-500843428988/09651aab-8486-42ec-a07e-8c94ea6f3709/_apis/work/boards/b31d634b-b573-4393-bfeb-5af850b9dbab",
        "name":  "Epics"
    },
    {
        "id":  "c2aef67c-637f-4295-bfef-e5d8c24fa7e8",
        "url":  "https://dev.azure.com/tommclaughlin/dc5329bd-bc74-48bb-af94-500843428988/09651aab-8486-42ec-a07e-8c94ea6f3709/_apis/work/boards/c2aef67c-637f-4295-bfef-e5d8c24fa7e8",
        "name":  "Features"
    }
]

.LINK 
https://docs.microsoft.com/en-us/rest/api/vsts/work/boards/list?view=vsts-rest-4.1

.LINK
Get-KanbanColumns

#>
function Get-KanbanBoards {
    [CmdletBinding()]
	Param(
        [Parameter(Position=0)][string]$team
    )

    $config = Get-VstsConfig
	$uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/$team/_apis/work/boards?api-version=4.1"

    Invoke-RestMethod -Uri $uri -Method Get -Headers $config.GetHeaders() -Verbose:$VerbosePreference
}

<#
.SYNOPSIS
Gets the columns of a particular board
.PARAMETER board
The name of the board to retrieve, e.g. "Stories"

.PARAMETER team
The name of the team.  If not specified, the default team will be used.

.EXAMPLE
(Get-KanbanColumns -board Stories -team "FakeTeam").value | convertto-json

.LINK
https://docs.microsoft.com/en-us/rest/api/vsts/work/columns?view=vsts-rest-4.1

.LINK
Get-KanbanBoards

#>
function Get-KanbanColumns {
    [CmdletBinding()]
	Param(
        [Parameter(Mandatory, Position=0)][string]$board,
        [string]$team
	)
    $config = Get-VstsConfig

	$uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/$team/_apis/work/boards/$board/columns?api-version=4.1"

    Invoke-RestMethod -Uri $uri -Method Get -Headers $config.GetHeaders() -Verbose:$VerbosePreference -Debug

}

<#
.SYNOPSIS
Sets Kanban columns for Board

.DESCRIPTION
Use this along with Get-KanbanColumns.  You'll need to get the original list of columns, then modify it.  There is no
"add" or "remove" column feature here yet. 

.EXAMPLE
(Get-KanbanColumns -board Stories -team "FakeTeam").value | convertto-json | Out-File -FilePath cols.json
# edit the file to match whatever columns we want...
# note that you can't change the Incoming or Outgoing columns
$cols = get-content -raw cols.json | convertfrom-json 
(Set-KanbanColumns -Team Faketeam -Board Stories -Columns $cols -Verbose).value
#>
function Set-KanbanColumns {
    [CmdletBinding()]
	Param(
        [Parameter(Mandatory, Position=0)][string]$board,
        [Object[]]$columns,
        [string]$team
	)
    $config = Get-VstsConfig

	$uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/$team/_apis/work/boards/$board/columns?api-version=4.1"

    $body = ConvertTo-Json $columns
    Write-Verbose $body
    Invoke-RestMethod -Uri $uri -Method PUT -body $body -Headers $config.GetHeaders() -Verbose:$VerbosePreference -Debug -ContentType "application/json"

}

<#
.SYNOPSIS
Gets team settings, e.g. bugsBehavior, working days, backlog visiblity, default iteration.

.EXAMPLE
# get settings for the current project's default team
Get-Teamsettings

.EXAMPLE
Get-Teamsettings "Netscaler Forms"

.PARAMETER Team
The team to retrieve.  If no team is given, gets the settings for the default team.

.LINK
https://docs.microsoft.com/en-us/rest/api/vsts/work/teamsettings/get?view=vsts-rest-4.1
#>
function Get-Teamsettings {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0)][string]$team
    )
    $config = Get-VstsConfig
    $uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/$team/_apis/work/teamsettings?api-version=4.1"

    Invoke-RestMethod -Uri $uri -Method GET -Headers $config.GetHeaders() -Verbose:$VerbosePreference 
}

<#
.SYNOPSIS
Update a team's settings, e.g. set its bugsBehavior

.PARAMETER team
The team whose settings are to be set.  If omitted, the project's default team will be used.

.PARAMETER settings
Settings to use.  See documentation link for details.

.EXAMPLE
# change setting for FakeTeam so that bugs are tracked with requirements (stories) rather
# than with tasks (which would be "asTasks")
Set-Teamsettings -verbose -team FakeTeam -settings @{ bugsBehavior="asRequirements" }

.LINK
https://docs.microsoft.com/en-us/rest/api/vsts/work/teamsettings/update?view=vsts-rest-4.1
#>
function Set-Teamsettings {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param(
        [string]$team,
        [Parameter(Mandatory=$true)]$settings
    )

    $config = Get-VstsConfig
    $uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/$team/_apis/work/teamsettings?api-version=4.1"

    if(!$team){
        Write-Warning "Using default team for '$($config.project)'.  Use -Team to specify team." 
    }

    $body=ConvertTo-Json $settings
    Write-Verbose $body
    if($PSCmdlet.ShouldProcess("set team settings")){
        Invoke-RestMethod -Uri $uri -Body $body -Method PATCH -ContentType "application/json" -Headers $config.GetHeaders() -Verbose:$VerbosePreference -Debug
    }
}

function Get-WorkItemsByBuild{
[CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)][int]$id
	    )
	
    $config = Get-VstsConfig
    $uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/_apis/build/builds/${id}/workitems?api-version=4.1"
   
    write-verbose $uri
    $result = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $config.GetHeaders()
    if($result -Is [String]) {
        Write-Error $result
        throw "Rest Method Failed!"
    }
	
	$json = ConvertTo-Json $result
				
    return $json

}

function Get-WorkItemsIdByBuild{
[CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)][int]$id
    )
   
	$ids = Get-WorkItemsByBuild $id | convertfrom-json 
	
	foreach ($line in $ids.value) {
		 $line.id
	}
}

<#
.SYNOPSIS
Updates a Work Item

.PARAMETER id 
Id of the work item.
.PARAMETER fields
A map of fields, e.g.
@{ 
	"System.Title"="my task"
	"System.Description"="my description"
	"System.AssignedTo"="gaurav.shrestha@nebraska.gov" 
	"Custom.Action"="some action"
}

#>
function Update-WorkItem {
    [CmdletBinding()]
    Param(
		[Parameter(Position=0, Mandatory=$true)][int]$id,
		[Parameter(Mandatory=$true,Position=1)]$fields
    )
    $config = Get-VstsConfig
	
	$uri = "https://dev.azure.com/$($config.AccountName)/$($config.Project)/_apis/wit/workitems/${id}?api-version=4.1"
	
	write-verbose $uri
	$patches = New-Object System.Collections.Generic.List[System.Object] 
	
	foreach($e in $fields.GetEnumerator()){
	
		$patches.Add(@{
			op="add"
			path="/fields/$($e.Name)"
			value=$e.Value
		})
	}

	$body=ConvertTo-Json $patches
	write-verbose $body
	
	 Invoke-RestMethod -Uri $uri -Body $body -Method PATCH -ContentType "application/json-patch+json" -Headers $config.GetHeaders() -Verbose:$VerbosePreference -Debug

}


Export-ModuleMember VstsConfig
Export-ModuleMember Set-VstsConfig
Export-ModuleMember Get-VstsConfig
Export-ModuleMember Find-ReleaseDefinition
Export-ModuleMember Get-ReleaseDefinition
Export-ModuleMember Find-Project
Export-ModuleMember Find-ServiceEndpoint
Export-ModuleMember Get-ServiceEndpoint
Export-ModuleMember New-Release
Export-ModuleMember Get-WorkItem
Export-ModuleMember Get-WorkItemFields
Export-ModuleMember Get-WorkItemTypes
Export-ModuleMember New-WorkItem
Export-ModuleMember Get-AllAzureDevOpsUsers 
Export-ModuleMember Get-KanbanColumns
Export-ModuleMember Set-KanbanColumns
Export-ModuleMember Get-KanbanBoards
Export-ModuleMember Get-Teamsettings
Export-ModuleMember Set-Teamsettings
Export-ModuleMember Get-WorkItemsByBuild
Export-ModuleMember Get-WorkItemsIdByBuild
Export-ModuleMember Update-WorkItem
