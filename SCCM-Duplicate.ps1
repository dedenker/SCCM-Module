# Basic grabbed from:
# http://myitforum.com/myitforumwp/2013/11/13/copy-sccm-2007-programs-with-powershell/
# Will be used as a additional cmdlet in the main module.


Param($OldPackageID,$OldProgramName,$NewPackageID,$NewProgramName)

# Enviromental Settings
$strCentralSiteServer = “CentralServerName”
$strCentralSiteCode = “ABC”

#grabbing a hold of the old package
    $OldProgramPackage = Get-WmiObject -computername $strCentralSiteServer -Namespace “root\sms\site_$($strCentralSiteCode)” -query “Select * from sms_package where packageid = ‘$($OldPackageID)’”

#grabbing a hold of the old program
    $OldProgramProgram = Get-WmiObject -computername $strCentralSiteServer -Namespace “root\sms\site_$($strCentralSiteCode)” -query “Select * from sms_program where packageid = ‘$($OldPackageID)’ and ProgramName = ‘$($OldProgramName)’”

<#
    Using the WMI path method to get the program properties.  Without going into too much detail, the supported platforms value
    copies this way.  If i just used $Prog.SupportedPLatform, the values do not migrate to the new program.
#>

    $OldProgramPath = “\\$($strCentralSiteServer)\root\sms\site_$($strCentralSiteCode):SMS_Program.PackageID=’$($OldProgramPackage.packageid)’,ProgramName=’$($OldProgramName)’”
    $prog = [WMI]$OldProgramPath

#Creating a new instance of the program, assigning it to the new package, and configuring the settings for the program.
    $NewProgram = ([WmiClass](“\\$script:strCentralSiteServer\root\sms\site_”+$script:strCentralSiteCode+”:SMS_Program”)).CreateInstance()

    $NewProgram.ActionInProgress = $prog.ActionInProgress
    $NewProgram.ApplicationHierarchy = $prog.ApplicationHierarchy
    $NewProgram.CommandLine = $prog.CommandLine
    $NewProgram.Comment = $prog.Comment
    $NewProgram.DependentProgram = $prog.DependentProgram
    $NewProgram.Description = $prog.Description
    $NewProgram.DeviceFlags = $prog.DeviceFlags
    $NewProgram.DiskSpaceReq = $prog.DiskSpaceReq
    $NewProgram.DriveLetter = $prog.DriveLetter
    $NewProgram.Duration = $prog.Duration
    $NewProgram.ExtendedData = $prog.ExtendedData
    $NewProgram.ExtendedDataSize = $prog.ExtendedDataSize
    $NewProgram.Icon = $prog.Icon
    $NewProgram.IconSize = $prog.IconSize
    $NewProgram.ISVData = $prog.ISVData
    $NewProgram.ISVDataSize = $prog.ISVDataSize
    $NewProgram.MSIFilePath = $prog.MSIFilePath
    $NewProgram.MSIProductID = $prog.MSIProductID
#New PackageID
    $NewProgram.PackageID = $NewPackageID
    $NewProgram.ProgramFlags = $prog.ProgramFlags
#New ProgramName
    $NewProgram.ProgramName = $NewProgramName
    $NewProgram.RemovalKey = $prog.RemovalKey
    $NewProgram.Requirements = $prog.Requirements
    $NewProgram.SupportedOperatingSystems = $prog.SupportedOperatingSystems
    $NewProgram.WorkingDirectory = $prog.WorkingDirectory

#Saving the new program.
    $NewProgram.put()
