#!/bin/env pwsh
Import-Module -Force $PSScriptRoot\VstsUtils.psm1
# using module $PSScriptRoot\VstsUtils.psm1

# $releaseDef = Find-ReleaseDefinition "rev-mef-deploy"
# $id = $releaseDef.id
# New-Release "$id"
#
#
Get-WorkItem 1 -verbose

# Find-BuildDefinition '*'
