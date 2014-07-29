#======================================================================================================================
# AUTHOR:	Tao Yang
# DATE:		20/05/2011
# Name:		Locate-SCCMObject.PS1
# Version:	1.0
# COMMENT:	Use this script to locate a SCCM object in SCCM Console. Please note it does not work for SCCM collections.
# Usage:	.\Locate-SCCMObject.ps1 <SCCM Central Site Server> <SCCM Object ID>
#======================================================================================================================

param([string]$CentralSiteServer,[string[]]$ObjID)

Function Get-SCCMObjectType ($ObjType)
{
	Switch ($objType)
	{
		2 {$strObjType = "Package"}
		3 {$strObjType = "Advertisement"}
		7 {$strObjType = "Query"}
		8 {$strObjType = "Report"}
		9 {$strObjType = "Metered Product Rule"}
		11 {$strObjType = "ConfigurationItem"}
		14 {$strObjType = "Operating System Install Package"}
		17 {$strObjType = "State Migration"}
		18 {$strObjType = "Image Package"}
		19 {$strObjType = "Boot Image Package"}
		20 {$strObjType = "TaskSequence Package"}
		21 {$strObjType = "Device Setting Package"}
		23 {$strObjType = "Driver Package"}
		25 {$strObjType = "Driver"}
		1011 {$strObjType = "Software Update"}
		2011 {$strObjType = "Configuration Item (Configuration baseline)"}
		default {$strObjType = "Unknown"}
	}
	Return $strObjType
}

Function Get-ConsolePath ($CentralSiteProvider, $CentralSiteCode, $SCCMObj)
{
	$ContainerNodeID = $SCCMObj.ContainerNodeID
	$strConsolePath = $null
	$bIsTopLevel = $false
	$objContainer = Get-WmiObject -Namespace root\sms\site_$CentralSiteCode -Query "Select * from SMS_ObjectContainerNode Where ContainerNodeID = '$ContainerNodeID'" -ComputerName $CentralSiteProvider
	$strConsolePath = $objContainer.Name
	$ParentContainerID = $objContainer.ParentContainerNodeID
	if ($ParentContainerID -eq 0)
	{
		$bIsTopLevel = $true
	} else {
		$strIDPath = "$ParentContainerID" + "`\" + "$ContainerNodeID"
		Do
		{
			$objParentContainer = Get-WmiObject -Namespace root\sms\site_$CentralSiteCode -Query "Select * from SMS_ObjectContainerNode Where ContainerNodeID = '$ParentContainerID'" -ComputerName $CentralSiteProvider
			$strParentContainerName = $objParentContainer.Name
			$strConsolePath = $strParentContainerName +"`\"+$strConsolePath
			$ParentContainerID = $objParentContainer.ParentContainerNodeID
			$strIDPath = "$ParentContainerID" + "`\" +  "$strIDPath"
			Remove-Variable objParentContainer, strParentContainerName
			if ($ParentContainerID -eq 0) {$bIsTopLevel = $true}
		} until ($bIsTopLevel -eq $true)
	}
	Return $strConsolePath, $strIDPath
}
$objSite = Get-WmiObject -ComputerName $CentralSiteServer -Namespace root\sms -query "Select * from SMS_ProviderLocation WHERE ProviderForLocalSite = True"
$CentralSiteCode= $objSite.SiteCode
$CentralSiteProvider = $objSite.Machine
$SCCMObj = Get-WmiObject -Namespace root\sms\site_$CentralSiteCode -Query "Select * from SMS_ObjectContainerItem Where InstanceKey = '$objID'" -ComputerName $CentralSiteProvider
If ($SCCMObj -eq $null){
	Write-Host "SCCM Object with ID $objID cannot be found!" -ForegroundColor Red
} else {
	$strObjType = Get-SCCMObjectType $SCCMObj.ObjectType
	$strConsolePath = Get-ConsolePath $CentralSiteProvider $CentralSiteCode $SCCMObj
	Write-Host "Object Type`: $strObjType" -ForegroundColor Yellow
	Write-Host "Console Path`: [ROOT]",$strConsolePath[0] -ForegroundColor Yellow
	Write-Host "Path Node numbers`: ",$strConsolePath[1] -ForegroundColor Yellow
}
