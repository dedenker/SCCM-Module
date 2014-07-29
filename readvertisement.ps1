#
#	Created by: JanPaul Klompmaker
#	Date: 29 Juli 2014
#
#	This will read an advertisement and creates a new one.
#	With a new package, links it to the existing collection.
#	Useful when to update already deployed clients with new source
#
#### Module Import ####
import-module "C:\dell\sccm-commands.psm1"

function duplicate_pkg($pkgid) {
	Get-SCCMPackage $server "Packageid='$pkgid'" | foreach { 
		new-sccmpackage $server -name $_.Name -Description $_.Description -language $_.Language -manufacturer $_.Manufacturer -pkgsourcepath $_.PkgSourcePath -version $_.Version | foreach {
			$newpkg = $_.Packageid
		}
	}
	return $newpkg
}
	
function duplicate_prog($pkgid,$newpkg) {
	"Duplicate Program from $pkgid in to $newpkg"
	Get-SCCMProgram $server -packageid "$pkgid" | foreach {
		$ProgramName = $_.ProgramName
		New-SCCMProgram $server -PrgName $ProgramName -PrgPackageID $newpkg -PrgComment $_.Comment -PrgCommandline $_.Commandline -PrgMaxRunTime $_.Duration -PrgSpaceReq $_.DiskSpaceReq -PrgWorkDir $_.WorkingDirectory
	}
}

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

Function Get-ConsolePath ($CentralSiteProvider, $CentralSiteCode, $SCCMObj,$SccmServer){
	$ContainerNodeID = $SCCMObj.ContainerNodeID
	$strConsolePath = $null
	$bIsTopLevel = $false
	$objContainer = Get-WmiObject -Namespace root\sms\site_$CentralSiteCode -Query "Select * from SMS_ObjectContainerNode Where ContainerNodeID = '$ContainerNodeID'" -ComputerName $CentralSiteProvider
	$strConsolePath = $objContainer.Name
	$ParentContainerID = $objContainer.ParentContainerNodeID
	if ($ParentContainerID -eq 0)
	{
		$bIsTopLevel = $true
		$strIDPath = "[0]" + "`\ " + "$ContainerNodeID"
	} else {
		$strIDPath = "$ParentContainerID" + "`\" + "$ContainerNodeID"
		Do
		{
			$objParentContainer = Get-WmiObject -Namespace $SccmServer.Namespace -Query "Select * from SMS_ObjectContainerNode Where ContainerNodeID = '$ParentContainerID'" -ComputerName $SccmServer.Machine
			$strParentContainerName = $objParentContainer.Name
			$strConsolePath = $strParentContainerName +"`\"+$strConsolePath
			$ParentContainerID = $objParentContainer.ParentContainerNodeID
			$strIDPath = "$ParentContainerID" + "`\" +  "$strIDPath"
			Remove-Variable objParentContainer, strParentContainerName
			if ($ParentContainerID -eq 0) {$bIsTopLevel = $true}
		} until ($bIsTopLevel -eq $true)
	}
	Return $strIDPath, $strConsolePath
}

function locateobj ($SccmServer, $ObjID) {
		$CentralSiteServer = $SccmServer.machine
		$objSite = Get-WmiObject -ComputerName $CentralSiteServer -Namespace root\sms -query "Select * from SMS_ProviderLocation WHERE ProviderForLocalSite = True"
		$CentralSiteCode= $objSite.SiteCode
		$CentralSiteProvider = $objSite.Machine
		$SCCMObj = Get-WmiObject -Namespace $SccmServer.Namespace -Query "Select * from SMS_ObjectContainerItem Where InstanceKey = '$objID'" -ComputerName $SccmServer.Machine
		If ($SCCMObj -eq $null){
			Write-Host "SCCM Object with ID $objID cannot be found!" -ForegroundColor Red
		} else {
			$strObjType = Get-SCCMObjectType $SCCMObj.ObjectType
			$strConsolePath = Get-ConsolePath $CentralSiteProvider $CentralSiteCode $SCCMObj $SccMServer
			Write-Host "Object Type`: $strObjType" -ForegroundColor Yellow
			Write-Host "Console Path`: [ROOT]\",$strConsolePath[1] -ForegroundColor Yellow
			Write-Host "Path Node numbers`: ",$strConsolePath[0] -ForegroundColor Yellow
		}
	$oldid = $SCCMObj.ContainerNodeID
	return $oldid
}
	##### MAIN #####
if($args.Length -eq 0){
	write-warning "No Advertisement ID Given!";
	Get-SCCMAdvertisement $server | foreach { $_.AdvertisementName , $_.AdvertisementID, $_.PackageID; "" }
	break
}
foreach ($advid in $args)
	{
	Get-SCCMAdvertisement $server "AdvertisementID='$($advid)'" | foreach {
		"Duplicate Package"
		$newpkg = duplicate_pkg $_.PackageID
		"New " + $newpkg
		duplicate_prog $_.packageID $newpkg
		New-SCCMAdvertisement $server -AdvertisementName $_.AdvertisementName -collectionID $_.CollectionID -PackageID $newpkg -ProgramName "$_.ProgramName" | foreach {
			"New Advertisement: ", $_.AdvertisementID
		}
		$moveID = locateobj $Server $_.PackageID
		"Moving Object to same location"
		Move-SCCMPackageToFolder -SccmServer $server -packageid $newpkg $moveID
		if($advid = "cleanup"){
			"Doing old package Clean up!"
			Remove-SCCMAdvertisement $server $_.AdvertisementID confirmed
			#Remove-SCCMPackage $server $_.PackageID confirmed
		}
	}
	
}
"If all successful, the old one can be deleted."
