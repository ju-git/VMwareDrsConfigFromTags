<#

==================== Author =================================================

Original script : Julien AILHAUD -  Mail :    julien 
                                              at ailhaud dot com
                                    
                                    LinkedIn  : Julien AILHAUD
                                    https://www.linkedin.com/in/julien-ailhaud-ba6bb6/
                                    
                                    Facebook  : Julien AILHAUD
                                    https://www.facebook.com/julien.ailhaud/
                                    
                                    Twitter   : @curbans
                                    https://twitter.com/curbans
                                    (Don't use Twitter)

Software hosted at : https://github.com/ju-git/VMwareDrsConfigFromTags

==================== Changelog ==============================================

Version : 2022.06.02.0001
    - Initial release.
    - Change Rules and VM to host rules only when enable status or related objects were changed.
    - Avoid redundant updates when a VM or Host Group is used in more than one rule.
    - Display a warning when the DrsRulesFile AND DeleteEveryRuleAndGroup params are given, 
      to point that the delete code don't read things from the Rules file.

==================== License =================================================

BSD 3-Clause License

Copyright (c) 2022, Julien AILHAUD
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


==================== Todo list ========================================

Known issues : 
    - Not tested on complex VMware setup (Linked Mode, ...)

Core code
    - Replace -match by -eq when it's appropriate
    - Use Functions ? :)
    - Use local credential store of Windows ?
    - Create Automated tests for CI/CD
    - Gain skills about PS exceptions management and use them
    - Create GUI to create the DRS rules file.
    - Enforce max length of the rule names (Max rulename size is 80 char.
      You can Limit your tags to 29 chars to avoid any issue)
    - Tool to create the configuration from existing, manually made DRS settings ?
    
English text
    - Fix english text
    - Put all messages in vars
    - Make messages more uniform

#>

<#

.SYNOPSIS 
  Script to create VMware DRS Groups and rules based on VMware Tags and a rules file. 
  
.DESCRIPTION 
  The scripts reads an Rules file (default : .\drs_rules\drs.csv), and Tags placed on VMs and Hosts.
  
  Based on this, it creates all needed DRS Groups and Rules.
  
  The script is idempotent, when it's re-run, it will update what needed,
  or do nothing if nothing changed in the inputs.
  
  
  FAQ : 
  
  Q: What is this script ?
  A: It creates DRS Rules based on a rules file and tags placed on VMs and hosts.

  Q: Why did you create it ?
  A: If you have lots of VMs/Clusters/hosts, maintaining the DRS settings is boring, and everything is manual.
  
  Q: Why not a Tags-Only solution ?
  A: It was my original idea/goal, but was found to be either too limited (only one rule
     for each VM group) or too complicated (need to create per-rule specific tags and assign
     lots of tags).
  
  Q: When should I run this script ?
  A: Just after you assigned/removed tags used for your rules, or changed/added rules in the rules file.
     If you want you can run it periodicaly, no issue.
     You can also start it from the VCBA when a tag is added.
  
.NOTES 
  Script created because vSphere only allows to create groups and rules based on static VM lists, hard to maintain when you have lots of VMs.

.EXAMPLE 

  Simple syntax :

  .\createDrsTagRules.ps1 
  
  The name of the vCenter to connect to and the needed credentials will be prompted on first
  start, and will be saved in the .\script_config\ folder.
  
.EXAMPLE 

  Working on only one of the clusters listed in the Rules File.

  .\createDrsTagRules.ps1 -Cluster ClusterName

.EXAMPLE 

  Working with an alternative Rules file.

  .\createDrsTagRules.ps1 -DrsRulesFile .\Path\To\CustomFile.csv 
  
.EXAMPLE 

  Working with an alternative Credentials file.

  .\createDrsTagRules.ps1 -CredentialsFile .\Path\To\myCreds.file 

.EXAMPLE 

  Exit after the Rules Files was tested (No modification is performed on the vCenter).

  .\createDrsTagRules.ps1 -DrsRulesFileValidationOnly 

.EXAMPLE 

  Delete DRS Groups and Rules created by the sctipt.
  
  .\createDrsTagRules.ps1 -DeleteEveryRuleAndGroup
  
  The elements to delete are identified based on their name, which is prefixed by the string "TAG", hardcoded in the script.
  
  A list is displayed, and the user has to confirm before anything is deleted.

.PARAMETER Cluster
  Name of a specific cluster. The rules from the Rules File will be filtered to work only on the rules for this cluster.
  If the parameter is not used, the default behaviour is to create all rules found in the Rules File.
.PARAMETER DrsRulesFile
  Name of the file containing the DRS Rules. By default, .\drs_rules\drs.csv
.PARAMETER CredentialsFile
  Name of the file containing the credentials to acces the vCenter. By default, .\script_config\powercliCreds.xml
  If the file doesn't exist, credentials will be asked and saved in the file.
.PARAMETER DeleteEveryRuleAndGroup
  If this switch is used or set to $true, the Remove code will be executed.
  It will remove all Rules/VM to Host Rules/groups named after the Prefix hardcoded in the script ("TAG")
.PARAMETER DrsRulesFileValidationOnly
  If this switch is used or set to $true, the script will exit after the validation step.
  No modification will be performed on the vSphere server.
.PARAMETER ForceInvalidDrsRulesFile
  If this switch is used or set to $true, the script will continue, event if the content of the DRS Rules file is not correct.
  (NOT IMPLEMENTED YET. THIS SWITCH WILL JUST SKIP THE VALIDATION STEP)
.PARAMETER SkipDrsRulesFileValidation
  If this switch is used or set to $true, the content of the DRS Rules file will be not be checked against incorrect entries.
.PARAMETER KeepLegacyDrsElements
  If this switch is used or set to $true, remove old elements step will be skiped.
  
.LINK 
  https://github.com/ju-git/VMwareDrsConfigFromTags

#>

param (
         [string]$Cluster="",
         [string]$DrsRulesFile="",
         [switch]$SkipDrsRulesFileValidation=$false,
         [switch]$DrsRulesFileValidationOnly=$false,
         [switch]$ForceInvalidDrsRulesFile=$false,
         [string]$CredentialsFile="",
         [switch]$DeleteEveryRuleAndGroup=$false,
         [switch]$KeepLegacyDrsElements=$false
      )

<#
  BIG WARNING : READ THIS !

  BIG WARNING : DO NOT CHANGE THESE 2 VALUES.

  If you finaly decide to change them : 
       - Never change them again
       - Apply your changes again if you upgrade the script to a new version

  If you miss something, the risks are :
       - Having orphaned and/or badly named rules
       - Deleting things not managed by the script when using the -DeleteEveryRuleAndGroup switch.
#>
Set-Variable prefixForDrsGroups -Option Constant -Value "TAG_"
Set-Variable prefixForDrsRules  -Option Constant -Value "TAG "

# Variables used to extract information from catch blocs.
# Created and initialised there... but are also initialised just when needed in the script.
$script:drsVmGroupAlreadyExists      = $true
$script:drsHostGroupAlreadyExists    = $true
$script:drsRuleAlreadyExists         = $true
$script:credentialsFileAlreadyExists = $true
$script:configFileAlreadyExists      = $false

# Variables lo list things created/updated by the script.
#$script:listDrsVmGroupAlreadyTested               = @() 
#$script:listDrsHostGroupAlreadyTested             = @()
#$script:listDrsClusterAlreadyTested               = @()
$script:listDrsVmGroupAlreadyComputed             = @() 
$script:listDrsHostGroupAlreadyComputed           = @()
$script:listDrsVmGroupAlreadyComputedWithPrefix   = @() 
$script:listDrsHostGroupAlreadyComputedWithPrefix = @()
$script:listDrsRulesAlreadyComputed               = @()

#
# Testing that the Rules file exists
#
if ( $DrsRulesFile.Length -eq 0 )
{
  $DrsRulesFile = ".\drs_rules\drs.csv"
  $DrsRulesFileProvidedByCommand = $false
}
else
{ 
  $DrsRulesFileProvidedByCommand = $true
}

try { Get-ChildItem $DrsRulesFile -ErrorAction Stop | Out-Null }
catch
{
  Write-Error   "Unable to open the rules file '$DrsRulesFile'. Exiting."
  exit
}

$testedDrsRulesFile = Get-ChildItem $DrsRulesFile
Write-Host "File"
Write-Host "DRS rules file found : $testedDrsRulesFile."

#
# Testing that the Credentials file exists
#
if ( $CredentialsFile.Length -eq 0 )
{
  $CredentialsFile = ".\script_config\powercliCreds.xml"
  $CredentialsFileProvidedByCommand = $false
}
else
{ 
  $CredentialsFileProvidedByCommand = $true 
}

$script:credentialsFileAlreadyExists = $true
try { Get-ChildItem $CredentialsFile -ErrorAction Stop | Out-Null }
catch
{
  $script:credentialsFileAlreadyExists = $false
}

if ( $script:credentialsFileAlreadyExists -ne $true )
{
  Write-Host ""
  Write-Warning   "Unable to open the credentials file '$CredentialsFile'."
  Write-Host      "Do you want to create it ? (you will be prompted for vCenter Credentials)."
  Read-Host -Prompt "  Type YES or NO "
  Get-Credential | Export-CliXml -Path $CredentialsFile | Out-Null
}
  
$testedCredentialsFile = Get-ChildItem $CredentialsFile
Write-Host ""
Write-Host "File"
Write-Host "Credentials file found : $testedCredentialsFile"

#
# Testing that the Configuration file exists
#
$ConfigFile = ".\script_config\script.conf"

$script:configFileAlreadyExists = $true
try { Get-ChildItem $ConfigFile -ErrorAction Stop | Out-Null }
catch
{
  $script:configFileAlreadyExists = $false
}

if ( $script:configFileAlreadyExists -ne $true )
{
  Write-Host ""
  Write-Warning   "Unable to open the configuration file '$ConfigFile'."
  Write-Host      "Do you want to create it ? (you will be asked for the vCenter name (FQDN or IP)."
  Read-Host -Prompt "  vCenter FQDN or IP Address : "  | Set-Content -Path $ConfigFile | Out-Null
}
  
$testedConfigFile = Get-ChildItem $ConfigFile
Write-Host ""
Write-Host "File"
Write-Host "Config file found : $testedConfigFile"
$vcsaToConnect = Get-Content $testedConfigFile
Write-Host "  vCenter : $vcsaToConnect."

#
# Connecting to the vCenter
#
$powerCliCredz=Import-CliXml -Path $testedCredentialsFile

try { Connect-VIServer $vcsaToConnect  -Credential $powerCliCredz -ErrorAction Stop | Out-Null }
catch
{
  Write-Host ""
  Write-Error   "Unable to connect to the vCenter. Exiting."
  Write-Error $error[1]
  exit
}

Write-Host ""
Write-Host "vCenter"
Write-Host "Connected to vCenter : $vcsaToConnect"

#
# Testing the Cluster parameter.
#
if ( $Cluster.Length -gt 0 )
{
  try { $paramCluster = Get-Cluster $Cluster -ErrorAction Stop | Out-Null }
  catch
  { 
    Write-Warning "The '$Cluster' cluster doesn't exists." 
    Write-Error   "The '$Cluster' cluster given as command line parameter -Cluster doesn't exists. Exiting."
    exit
  }
  
  Write-Host ""  
  Write-Host "Cluster"
  Write-Host "Working on cluster '$Cluster'."
}
else
{ 
  $paramCluster = $false
  
  Write-Host ""  
  Write-Host "Cluster"
  Write-Host "  No cluster provided. Working all clusters listed in the rules file."
  
}

#
# If the $DeleteEveryRuleAndGroup parameter is used, we remove all Rules/VM to Host Rules/groups 
# named after the Prefix hardcoded in the script.
#
# No way to skip confirmation, for security reason, 
#
if ( $DeleteEveryRuleAndGroup )
{
  if ( $DrsRulesFileProvidedByCommand )
  {
    Write-Warning "The DeleteEveryRuleAndGroup functionnality doesn't work with the rule files."
    Write-Warning "You can't invoke the script with both -DeleteEveryRuleAndGroup and -DrsRulesFile parameters."
    Write-Error "-DeleteEveryRuleAndGroup and -DrsRulesFile parameters found in command line. Exiting."
    exit
  }
  
  if ( $paramCluster )
  {
    $drsRulesToDelete         = Get-Cluster $paramCluster | Get-DrsRule
    $drsVMHostRulesToDelete   = Get-Cluster $paramCluster | Get-DrsVMHostRule
    $drsClusterGroupsToDelete = Get-Cluster $paramCluster | Get-DrsClusterGroup
  }
  else
  {
    $drsRulesToDelete         = Get-Cluster | Get-DrsRule
    $drsVMHostRulesToDelete   = Get-Cluster | Get-DrsVMHostRule
    $drsClusterGroupsToDelete = Get-Cluster | Get-DrsClusterGroup
  }
  
  Write-Host ""
  Write-Host "These DRS Rules will be deleted : "
  Write-Host $drsRulesToDelete 
  Write-Host ""
  Write-Host "These DRS VM to Host Rules will be deleted : "
  Write-Host $drsVMHostRulesToDelete 
  Write-Host ""
  Write-Host "These DRS Cluster Groups will be deleted : " 
  Write-Host $drsClusterGroupsToDelete
  Write-Host ""
  Write-Warning "All the DRS Rules, VM to Host Rules, and DRS Groups listed there will be DELETED !!"
  Write-Host ""
  
  # No way to skip confirmation, for security reason.
  $confirmDeletion = Read-Host -Prompt "  Type 'I AM SURE' to confirm. "
  
  if ( $confirmDeletion -eq "I AM SURE" )
  {
    $drsRulesToDelete         | Remove-DrsRule -Confirm:$false
    $drsVMHostRulesToDelete   | Remove-DrsVMHostRule -Confirm:$false
    $drsClusterGroupsToDelete | Remove-DrsClusterGroup -Confirm:$false
  }
  else
  {
    Write-Warning "No confirmation received from user. Deleting nothing and exiting."
  }
  
  
  Write-Host ""
  Write-Host "vCenter"
  Disconnect-VIServer -Server $vcsaToConnect -Confirm:$false 
  Write-Host "Disconnected from vCenter : $vcsaToConnect"
  Write-Host ""
  Write-Host "End of script."
  
  exit
}

# If the -Cluster parameter is used, the rules file is filtered.
if ( $Cluster.Length -gt 0 ) 
{
  # Load the file with filter on the Cluster
  $drsRulesFiltered = import-csv $testedDrsRulesFile  -Delimiter ";"  | where { $_.DrsClusterName -eq $Cluster } 
}
else
{
  # Load the file.
  $drsRulesFiltered = import-csv $testedDrsRulesFile  -Delimiter ";"  
}


#
#
# Browse loaded data to check that the rules file point to existing and affected tags
#
# 

if ( $ForceInvalidDrsRulesFile )
{
  Write-Host ""
  Write-Warning "The -ForceInvalidDrsRulesFile option is not implemented yet."
  Write-Warning "Skipping validation instead."
  $SkipDrsRulesFileValidation = $true
}

if ( $SkipDrsRulesFileValidation -eq $false )
{

  $drsRulesFiltered | ForEach-Object  {
    
    $drsRuleTypeDisplay = $_.DrsRuleType
    
    Write-Host ""
    Write-Host "RuleTest"
    Write-Host $_

    if ( @("MustNotRunOn", "ShouldNotRunOn", "MustRunOn", "ShouldRunOn" , "KeepTogether" , "KeepSeparated" ).Contains($_.DrsRuleType) -eq $false )
    {
      Write-Warning "This RuleType ($drsRuleTypeDisplay) is not an accepted type."
      Write-Error "Accepted types are : MustNotRunOn, ShouldNotRunOn, MustRunOn, ShouldRunOn, KeepTogether, KeepSeparated"
      exit
    }
    Write-Host "Rule Type Allowed."
    
    
    # No DRS group for rules where DrsHostGroup is empty.
    if ( $_.DrsHostGroup.Length -lt 1 )
    {
      Write-Host "  No action when DrsHostGroup is empty. RuleType = '$drsRuleTYpeDisplay'."
      return
    }
    else
    { 
      #$newHostGroupId = -join( $_.Cluster , $_.DrsRuleType , $_.DrsHostGroup )  
      $newHostGroupName = $_.DrsHostGroup
      Write-Host "Working on Host Tag '$newHostGroupName' for rule of type '$drsRuleTYpeDisplay'."

      Write-Host "  Checking Hosts with needed Tag in the cluster."
      
      try { $hostsWithCurrentTag = Get-Cluster $_.DrsClusterName | Get-VMHost -Tag $_.DrsHostGroup -ErrorAction Stop }
      catch  
      {
        # If Ne ESXi, exit with error.
        Write-Warning "Error while getting list of hosts with the needed TAG." 
        Write-Error $Error[0]
       
       
        Write-Host ""
        Write-Host "vCenter"
        Disconnect-VIServer -Server $vcsaToConnect -Confirm:$false 
        Write-Host "Disconnected from vCenter : $vcsaToConnect"
        Write-Host ""
        Write-Host "End of script."
        Write-Host ""

       
       exit
      }
      
      if ( $hostsWithCurrentTag.Count -lt 1 )
      {
        $DrsHostGroup = $_.DrsHostGroup 
        $DrsClusterName = $_.DrsClusterName 
        Write-Error "No host with the needed TAG $DrsHostGroup was found in Cluster $DrsClusterName . Exiting."

        Write-Host ""
        Write-Host "vCenter"
        Disconnect-VIServer -Server $vcsaToConnect -Confirm:$false 
        Write-Host "Disconnected from vCenter : $vcsaToConnect"
        Write-Host ""
        Write-Host "End of script."
        Write-Host ""

        exit
      }
      else
      {
        Write-Host "  Hosts with needed TAG found."
      }
    }
    

    $newVmGroupName = $_.DrsVmGroup
    Write-Host "Working on VM Tag '$newVmGroupName' for rule of type '$drsRuleTYpeDisplay'."

    Write-Host "  Checking VMs with needed Tag in the cluster."
    
    try { $vmsWithCurrentTag = Get-Cluster $_.DrsClusterName | Get-VM -Tag $_.DrsVmGroup -ErrorAction Stop }
    catch  
    {
      # If No VM, exit with error.
      Write-Warning "Error while getting list of VMs with the needed TAG." 
      Write-Error $Error[0]
     
     
      Write-Host ""
      Write-Host "vCenter"
      Disconnect-VIServer -Server $vcsaToConnect -Confirm:$false 
      Write-Host "Disconnected from vCenter : $vcsaToConnect"
      Write-Host ""
      Write-Host "End of script."
      Write-Host ""

     
     exit
    }
    
    if ( $vmsWithCurrentTag.Count -lt 1 )
    {
      $DrsVmGroup = $_.DrsHostGroup 
      $DrsClusterName = $_.DrsClusterName 
      Write-Error "No VM with the needed TAG $DrsHostGroup was found in Cluster $DrsClusterName. Exiting."

      Write-Host ""
      Write-Host "vCenter"
      Disconnect-VIServer -Server $vcsaToConnect -Confirm:$false 
      Write-Host "Disconnected from vCenter : $vcsaToConnect"
      Write-Host ""
      Write-Host "End of script."
      Write-Host ""

      exit
    }
    else
    {
      $displayVmNumber = $vmsWithCurrentTag.Count
      Write-Host "  $displayVmNumber VM(s) with needed TAG found."
    }

    if ( $vmsWithCurrentTag.Count -lt 2 -and  @( "KeepTogether" , "KeepSeparated" ).Contains($_.DrsRuleType) -eq $true )
    {
      $DrsVmGroup = $_.DrsHostGroup 
      $DrsClusterName = $_.DrsClusterName 
      $DrsRuleType = $_.DrsRuleType
      Write-Error "Not enough VM with the needed TAG '$DrsVmGroup' was found in Cluster '$DrsClusterName'. 2 VMs are needed for Rules of type '$DrsRuleType', only $displayVmNumber was found. Exiting."

      Write-Host ""
      Write-Host "vCenter"
      Disconnect-VIServer -Server $vcsaToConnect -Confirm:$false 
      Write-Host "Disconnected from vCenter : $vcsaToConnect"
      Write-Host ""
      Write-Host "End of script."
      Write-Host ""

      exit
    }
    else
    {
      Write-Host "  Enough VM with needed TAG found."
    }
  }
}
else
{
  Write-Host ""
  Write-Warning "Using the -SkipDrsRulesFileValidation option is not recommended."
}

if ( $DrsRulesFileValidationOnly -eq $true )
{
  Write-Host ""
  Write-Host "Option -DrsRulesFileValidationOnly provided in the Command line. Exiting."
  exit
}

#
#
# Browse loaded data to create/update the "HOST Groups"
#
# 
$drsRulesFiltered | ForEach-Object  {
  
  Write-Host ""
  Write-Host "HostGroup"
  Write-Host $_
  
  # No DRS group for rules where DrsHostGroup is empty.
  if ( $_.DrsHostGroup.Length -lt 1 )
  {
    $drsRuleTYpeDisplay = $_.DrsRuleType
    Write-Host "  No action when DrsHostGroup is empty. RuleType = '$drsRuleTYpeDisplay'."
    return
  }
  else
  {
    
    #$newHostGroupTagName = $_.DrsHostGroup
    $newHostGroupName = -join( $prefixForDrsGroups , $_.DrsHostGroup )  
    
    # No action if Host Group was already computed.
    if ( $script:listDrsHostGroupAlreadyComputed.Contains(-join($_.DrsClusterName , " " , $_.DrsHostGroup) ) -eq $false )
    {
      $script:listDrsHostGroupAlreadyComputed += -join($_.DrsClusterName , " " , $_.DrsHostGroup)
      $script:listDrsHostGroupAlreadyComputedWithPrefix += -join($_.DrsClusterName , " " , $newHostGroupName)
    }
    else
    {
      Write-Host "  No action when DrsHostGroup was already computed by a previous rule."
      return
    }
    
    Write-Host "Working on Host Group '$newHostGroupName'."

    # List ESXi with the TAG
    try { $hostsWithCurrentTag = Get-Cluster $_.DrsClusterName | Get-VMHost -Tag $_.DrsHostGroup -ErrorAction Stop }
    catch  
    {
      # Si il n'y a aucun ESXi, sortie en echec.
     Write-Warning "This TAG is affected to no ESXi." 
     Write-Host ""
     return
    }

    $script:drsHostGroupAlreadyExists = $true
    # Vérification existance groupe.
    try  { Get-DrsClusterGroup -Cluster $_.DrsClusterName -Name $newHostGroupName -ErrorAction Stop | Out-Null}
    catch  { $script:drsHostGroupAlreadyExists = $false }

    if ( $script:drsHostGroupAlreadyExists )
    {
      Write-Host "Updating Host Group '$newHostGroupName'."
      $hostsAlreadyInDrsGroup = (Get-DrsClusterGroup -Cluster $_.DrsClusterName -name $newHostGroupName ).Member
      $hostsToAddIntoDrsGroup = (Compare-Object $hostsAlreadyInDrsGroup $hostsWithCurrentTag  | where { $_.SideIndicator -eq "=>" }  ).InputObject
      $hostsToRemoveFromDrsGroup = (Compare-Object $hostsWithCurrentTag $hostsAlreadyInDrsGroup  | where { $_.SideIndicator -eq "=>" }  ).InputObject
      
      if ( $hostsToRemoveFromDrsGroup.Count -gt 0 ) 
      {
        Write-Host "  Remove ESXi hosts '$hostsToRemoveFromDrsGroup'."
        Get-DrsClusterGroup -Cluster $_.DrsClusterName -name $newHostGroupName |  Set-DrsClusterGroup -Remove  -VMHost $hostsToRemoveFromDrsGroup | Out-Null
        Write-Host "  Removing unwanted ESXi's from the group."
      }
      else { Write-Host "  No ESXi host to remove." }
      
      
      if ( $hostsToAddIntoDrsGroup.Count -gt 0 )
      {
        Write-Host "  Remove ESXi hosts" $hostsToAddIntoDrsGroup
        Get-DrsClusterGroup -Cluster $_.DrsClusterName -name $newHostGroupName |  Set-DrsClusterGroup -Add -VMHost $hostsToAddIntoDrsGroup | Out-Null
        Write-Host "  Adding missing ESXi's into the group."
      }
      else { Write-Host "  No ESXi host to add." }
    }
    else
    {
      Write-Host "  Creating Host Group '$newHostGroupName'."
      New-DrsClusterGroup -Name $newHostGroupName -Cluster $_.DrsClusterName -VMHost $hostsWithCurrentTag | Out-Null
    }
  }
}

#
#
# Browse loaded data to create/update the "VM Groups"
#
#
$drsRulesFiltered | ForEach-Object  {

  Write-Host ""
  Write-Host "VMGroup"
  Write-Host $_

  # No DRS group for rules "KeepTogether" and "KeepSeparated".
  if ( $_.DrsRuleType -match "KeepSeparated" -or $_.DrsRuleType -match "KeepTogether" )
  {
    $drsRuleTYpeDisplay = $_.DrsRuleType
    Write-Host "  No action when DRS Rules Type = '$drsRuleTYpeDisplay'"
    return
  }
  else
  {
    
    ## $newVmGroupTagName = $_.DrsVmGroup
    $newVmGroupName = -join( $prefixForDrsGroups , $_.DrsVmGroup )  
    
    # No action if VM Group was already computed.
    if ( $script:listDrsVmGroupAlreadyComputed.Contains(-join($_.DrsClusterName , " " , $_.DrsVmGroup)) -eq $false )
    {
      $script:listDrsVmGroupAlreadyComputed += -join($_.DrsClusterName , " " , $_.DrsVmGroup)
      $script:listDrsVmGroupAlreadyComputedWithPrefix += -join($_.DrsClusterName , " " , $newVmGroupName)
    }
    else
    {
      Write-Host "  No action when DrsVmGroup was already computed by a previous rule."
      return
    }
    
    $drsRuleTypeDisplay = $_.DrsRuleType
    Write-Host "Working on VM Group for a VM to Host rule of Type = '$drsRuleTypeDisplay'."

    # List the VM with this TAG
    try { $vmsWithCurrentTag = Get-Cluster $_.DrsClusterName | Get-VM -Tag $_.DrsVmGroup -ErrorAction Stop }
    catch  
    {
      # If no VM, jumping to the next element of the loop.
     Write-Warning "This TAG is affected to no VM." 
     Write-Host ""
     return
    }
    
    # Checking if the group already exists.
    $script:drsVmGroupAlreadyExists = $true
    try  { Get-DrsClusterGroup -Cluster $_.DrsClusterName -Name $newVmGroupName -ErrorAction Stop | Out-Null }
    catch  { $script:drsVmGroupAlreadyExists = $false }

    if ( $script:drsVmGroupAlreadyExists )
    {
      Write-Host "Updating VM Group '$newVmGroupName'."
      $vmsAlreadyInDrsGroup = (Get-DrsClusterGroup -Cluster $_.DrsClusterName -name $newVmGroupName ).Member
      $vmsToAddIntoDrsGroup = (Compare-Object $vmsAlreadyInDrsGroup $vmsWithCurrentTag  | where { $_.SideIndicator -eq "=>" }  ).InputObject
      $vmsToRemoveFromDrsGroup = (Compare-Object $vmsWithCurrentTag $vmsAlreadyInDrsGroup  | where { $_.SideIndicator -eq "=>" }  ).InputObject
      
      if ( $vmsToRemoveFromDrsGroup.Count -gt 0 ) 
      {
        Get-DrsClusterGroup -Cluster $_.DrsClusterName -name $newVmGroupName |  Set-DrsClusterGroup -Remove  -VM $vmsToRemoveFromDrsGroup | Out-Null
        Write-Host "  Removing unwanted VMs from the group."
      }
      else { Write-Host "  No VM to remove." }
      
      if ( $vmsToAddIntoDrsGroup.Count -gt 0 )
      {
        Get-DrsClusterGroup -Cluster $_.DrsClusterName -name $newVmGroupName |  Set-DrsClusterGroup -Add -VM $vmsToAddIntoDrsGroup | Out-Null
        Write-Host "  Adding missing VMs into the group."
      }
      else { Write-Host "  No VM to add." }
    }
    else
    {
      Write-Host "  Creating group '$newVmGroupName'."
      New-DrsClusterGroup -Name $newVmGroupName -Cluster $_.DrsClusterName -VM $vmsWithCurrentTag | Out-Null
    }
  }
}

#
#
# Browse loaded data to create/update DRS Rules.
#
# 
$drsRulesFiltered | ForEach-Object  {

  # For rules "KeepTogether" and "KeepSeparated", an affinity rule will be created
  if ( $_.DrsRuleType -match "KeepSeparated" -or $_.DrsRuleType -match "KeepTogether" )
  {
    
    Write-Host ""
    Write-Host "DRSRule"
    Write-Host $_
    
    $drsRuleTypeDisplay = $_.DrsRuleType
    Write-Host "Working on rule of Rule Type = '$drsRuleTypeDisplay'."

    # "DrsClusterName" ;   "DrsRuleType"            ; ""                    ; "DrsHostGroup"                        ; "DrsRuleComment" ;
    $newDrsRuleName = -join($prefixForDrsRules, $_.DrsRuleType, " " , $_.DrsVmGroup )
    
    # Get list of VMs with the TAG
    try { $vmsWithCurrentTag = Get-Cluster $_.DrsClusterName | Get-VM -Tag $_.DrsVmGroup -ErrorAction Stop }
    catch  
    {
      # If no VM found with this TAG, going to next rule.
      Write-Warning "This TAG is affected to no VM." 
      Write-Host ""
      return
    }    
    
    if ( $_.DrsRuleEnabled -match "true")
    { $boolDrsRuleEnabled = $true }
    else
    { $boolDrsRuleEnabled = $false }
    
    if ( $_.DrsRuleType -match "KeepTogether" )
    { $keepTogetherOption=$true }
    else
    { $keepTogetherOption=$false }
    
    $currentDrsRule = $false
    $script:drsRuleAlreadyExists = $true
    try { $currentDrsRule = Get-DrsRule -Name $newDrsRuleName  -Cluster $_.DrsClusterName -ErrorAction Stop  }
    catch  { $script:drsRuleAlreadyExists = $false }
    
    if ( $script:drsRuleAlreadyExists )
    {  
      if ( $currentDrsRule.Enabled -ne $boolDrsRuleEnabled )
      {
        Set-DrsRule -Rule $currentDrsRule -VM $vmsWithCurrentTag -Enabled $boolDrsRuleEnabled | Out-Null
        Write-Host "  Existing rule '$newDrsRuleName' was updated."
      }
      else
      {
        Write-Host "  Existing rule '$newDrsRuleName' has not changed in the rules file."
      }
    }
    else
    {
      New-DrsRule -Name $newDrsRuleName -VM $vmsWithCurrentTag -Cluster $_.DrsClusterName -Enabled:$boolDrsRuleEnabled -KeepTogether:$keepTogetherOption  | Out-Null
      Write-Host "  Creating new rule '$newDrsRuleName'."
    }
    
    $script:listDrsRulesAlreadyComputed += -join($_.DrsClusterName , " " , $newDrsRuleName ) # I Know, this line can be at the upper level. But no.
    
  }

  # For rules of types MustRunOn, ShouldRunOn, MustNotRunOn, and ShouldNotRunOn,
  # a VM to Host Rule will be created.
  if ( @("MustNotRunOn", "ShouldNotRunOn", "MustRunOn", "ShouldRunOn" ).Contains($_.DrsRuleType))
  {
    
    Write-Host ""
    Write-Host "VM To Host Rule"
    Write-Host $_
    
    $drsRuleTypeDisplay = $_.DrsRuleType
    Write-Host "Working on rule of Rule Type = '$drsRuleTypeDisplay'."

    # "DrsClusterName" ;   "DrsRuleType"            ; ""                    ; "DrsHostGroup"                        ; "DrsRuleComment" ;
    $newDrsRuleName = -join($prefixForDrsRules, $_.DrsVmGroup , " " , $_.DrsRuleType, " " , $_.DrsHostGroup )
    
    $newDrsRuleHostgroupName = -join( $prefixForDrsGroups , $_.DrsHostGroup )  
    $newDrsRuleVmgroupName = -join( $prefixForDrsGroups , $_.DrsVmGroup )  
    
    if ( $_.DrsRuleEnabled -match "true")
    { $boolDrsRuleEnabled = $true }
    else
    { $boolDrsRuleEnabled = $false }
    
    $currentDrsRule = $false
    $script:drsRuleAlreadyExists = $true
    try { $currentDrsRule = Get-DrsVMHostRule -Name $newDrsRuleName  -Cluster $_.DrsClusterName -ErrorAction Stop  }
    catch  { $script:drsRuleAlreadyExists = $false }
    
    if ( $script:drsRuleAlreadyExists )
    { 
      if ( $currentDrsRule.Enabled -ne $boolDrsRuleEnabled )
      {
        Set-DrsVMHostRule   -Rule $currentDrsRule -Enabled:$boolDrsRuleEnabled | Out-Null
        Write-Host "  Existing rule '$newDrsRuleName' was updated."
      }
      else
      {
        Write-Host "  Existing rule '$newDrsRuleName' has not changed in the rules file."
      }
    }
    else
    {
      New-DrsVMHostRule -Name $newDrsRuleName  -Cluster $_.DrsClusterName -Enabled:$boolDrsRuleEnabled -Type $_.DrsRuleType -VMGroup $newDrsRuleVmgroupName -VMHostGroup $newDrsRuleHostgroupName | Out-Null
      Write-Host "  Creating new rule '$newDrsRuleName'."
    }
    
    $script:listDrsRulesAlreadyComputed += -join($_.DrsClusterName , " " , $newDrsRuleName ) # I Know, this line can be at the upper level. But no.
  }
}


#
# Removing Rules and Groups with script Prefix not found in the rules File.
#
if ( $KeepLegacyDrsElements -eq $false)
{
  
  # If the -Cluster parameter is used, the Rules list is filtered
  if ( $Cluster.Length -gt 0 ) 
  {
    # list the rules from the Cluster
    $existingDrsRuleList = Get-Cluster $Cluster | Get-DrsRule $prefixForDrsRules*
    $existingDrsVMHostRuleList  = Get-Cluster $Cluster |Get-DrsVMHostRule $prefixForDrsRules*
    $existingDrsClusterGroup  = Get-Cluster $Cluster | Get-DrsClusterGroup $prefixForDrsGroups*
  }
  else
  {
    # list the rules from all Clusters
    $existingDrsRuleList = Get-Cluster | Get-DrsRule  $prefixForDrsRules*
    $existingDrsVMHostRuleList  = Get-Cluster |Get-DrsVMHostRule $prefixForDrsRules*
    $existingDrsClusterGroup  = Get-Cluster | Get-DrsClusterGroup $prefixForDrsGroups*
  }
  
  $existingDrsRuleList | ForEach-Object  {
    
    Write-Host ""
    Write-Host "RemoveDRSRule"
    Write-Host "Working on rule :" $_.Name
    
    # if current Rule was not computed by the script, it doesn't exists anymore in the rules File. Removing it.
    if ( $script:listDrsRulesAlreadyComputed.Contains(-join($_.Cluster.Name , " " , $_.Name)) -eq $false )
    {
      $_ | Remove-DrsRule -Confirm:$false
      Write-Host "  The Rule is not in the Rules File anymore. Removed."
    }
    else
    { Write-Host "  The Rule was still found in the Rules File. No action." }
  }
  
  $existingDrsVMHostRuleList | ForEach-Object  {
    
    Write-Host ""
    Write-Host "RemoveDrsVMHostRule"
    Write-Host "Working on rule :" $_.Name
    
    # if current Rule was not computed by the script, it doesn't exists anymore in the rules File. Removing it.
    if ( $script:listDrsRulesAlreadyComputed.Contains(-join($_.Cluster.Name , " " , $_.Name)) -eq $false )
    {
      $_ | Remove-DrsVMHostRule -Confirm:$false
      Write-Host "  The VM to Host Rule was not in the Rules File anymore. Removed."
    }
    else
    { Write-Host "  The VM to Host Rule was still found in the Rules File. No action." }
  }
  
  
  # All the VM and Hosts groups computed by the script. Format :   "[ClusterName] [GrpPrefix][TagName]"
  $listDrsGroupWithPrefix = $script:listDrsHostGroupAlreadyComputedWithPrefix + $script:listDrsVmGroupAlreadyComputedWithPrefix
  
  $existingDrsClusterGroup | ForEach-Object  {
    
    Write-Host ""
    Write-Host "RemoveDrsClusterGroup"
    Write-Host "Working on DRS Group :" $_.Name
    
    # if current Rule was not computed by the script, it doesn't exists anymore in the rules File. Removing it.
    if ( $listDrsGroupWithPrefix.Contains(-join($_.Cluster.Name , " " , $_.Name)) -eq $false )
    {
      $_ | Remove-DrsClusterGroup -Confirm:$false
      Write-Host "  The DRS Group was not in the Rules File anymore. Removed."
    }
    else
    { Write-Host "  The DRS Group was still found in the Rules File. No action." }
  }
}
else
{
  Write-Host ""
  Write-Host "RemoveDRSRule"
  Write-Host "The -KeepLegacyDrsElements option was provided. Existing rules will purged."
}

Write-Host ""
Write-Host "vCenter"
Disconnect-VIServer -Server $vcsaToConnect -Confirm:$false 
Write-Host "Disconnected from vCenter : $vcsaToConnect"
Write-Host ""
Write-Host "End of script."
Write-Host ""

