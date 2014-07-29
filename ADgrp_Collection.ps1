#########################################################################################
#											
# 							SCCM 2007 group creation script	
# 								 2014 - March - 06	
# 								   Version: v0.1	
# 							Made by: JanPaul Klompmaker	
# 								For: PowerShell 2.0	
#											
#########################################################################################
#											
# This follows the standard that every office has his own "application" OU.		
# If this is not the case the office is not yet SCCM ready.				
# For now only works on EMEA region (this will be adjusted with a dropdown box)		
# Also a verification for the packages should be done...	
#
# !!!!!!!Please adjust to you own enviroment!!!!!!!!
#											
# First every real powershell script so forgive any mistakes, plus I am very imaginable with variable names
#											
#########################################################################################

## Modules
Import-Module ActiveDirectory

## Declare
$ready=0
$notready=0
$done=0
$todo=@()
$doname=@()

#This function is need to proper search for existing groups with variables
function check($args){
function groupExists ([string]$name){
	$string = "LDAP://CN=GRP_APP_$name,OU=Applications,OU=Security Groups,OU=GLOBAL,DC=COGLO,DC=COM"
	write-debug $string
	$result = [ADSI]::Exists($string)
	return $result
}
if($args.Length -eq 0){
	write-warning "No Name Given!";
	break
}
foreach ($arg in $args)
{
	Write-Host "Going for application group: $arg";
#	Searchbase EMEA - APAC - SCNA or Global!
	Foreach ($location in (Get-ADOrganizationalUnit -Filter 'Name -like "Security Groups"' -SearchBase 'OU=EMEA,DC=COGLO,DC=COM' | Get-ADObject))
	{
		if(!(Get-ADGroup -Filter "Name -like '*$arg*'" -SearchBase "$($location.DistinguishedName)" | Select Name,DistinguishedName)){
			if(!(Get-ADOrganizationalUnit -Filter 'Name -like "Applications"' -SearchBase "$($location.DistinguishedName)")) {
				$notready++
				Write-host "$($location.DistinguishedName) is not ready for $arg" -foregroundcolor "red";
			} else {
				$ready++
				$todo += $($location.DistinguishedName)
				write-host (Get-ADOrganizationalUnit -Filter 'Name -like "Applications"' -SearchBase "$($location.DistinguishedName)" | select @{n='Name';e={$_.DistinguishedName -replace "($_)Security Groups,",".."}})
				Write-host "$($location.DistinguishedName) has no $arg" -foregroundcolor "yellow";
			}
		} else {
			$done++
			Write-host "$($location.DistinguishedName) does has $arg" -foregroundcolor "green";
		}
	}
}
$answer = new-object -comobject "WScript.Shell"
$result = $answer.popup("$ready are Ready`n$notready are NOT READY`n$done are DONE!`nMake them?",0,"Question",4+32)
  if($result -eq 6){
	  write-host "Here we go!";
	  foreach ($do in ($todo)) {
		  write-debug $do;
		  foreach($name in (Get-ADGroup -Filter {name -like "*IT_Administrators*"} -SearchBase "$($do)" | Select Name ))
			  {
				  $ja = $name.name -replace "_(\w+)",""
				  $doname += $ja+"_APP_$arg&OU=Applications,$do"
				  break  # We break here so no extra's with the same name are trapped
			  }
	  }
	  Write-Host "Checking if group object exists";
	  if(groupExists ($arg))
	  {
		  write-Verbose "Group object present";
	  } else {
		  write-Verbose "The group object doesn't exists so should be made";
		  New-ADGroup -Path "OU=Applications,OU=Security Groups,OU=GLOBAL,DC=COGLO,DC=COM" -Name "GRP_APP_$arg" -GroupScope Global -GroupCategory Security -Description "Machine name based (Created by SCCM Application Script)"
	  }
	  write-host "Hier de lijst:";
	  foreach($name in $doname)	{
			write-debug $name 
			$tedoen = $name.Split("&") 
			write-host "Object:"$tedoen[0]
			write-host "Location:"$tedoen[1]
			New-ADGroup -Path $tedoen[1] -Name $tedoen[0] -GroupScope Global -GroupCategory Security -Description "Machine name based (Created by SCCM Application Script)"
			Add-ADGroupMember -Identity "GRP_APP_$arg" -Member $tedoen[0]
		}
  }
  if($result -eq 7){
	  write-host "Then NOT!";
  }
}
