###
#
#	Created by: JanPaul Klompmaker
#	Date:	19 Juli 2014
#	
######################
#
#	Adjust to your own environment!!!!!!!!!!!
#
###

### Modules ###

Import-Module msi
Import-Module ActiveDirectory
import-module "sccm-commands.psm1"
import-module "mysql.psm1"

### Declaring ###

$server = Connect-SCCMServer GISDCS93
#$insert = Prepare-MySQL -server '10.3.1.68' -user 'powershell' -password 'powershell' -database 'powershell'

### Functions ###

function Connect() {
	Prepare-MySQL -server '10.3.1.68' -user 'powershell' -password 'powershell' -database 'powershell'
	return
}

function NonQuery([string]$cmd) {
	$insert = Connect
		try {
			$insert.CommandText = $cmd
			$success = $insert.ExecuteNonQuery();
			}
		catch
			{
			"Command: ", $cmd
			"Inserting: ", $insert
			"Reply: ", $success
			
			}
	$insert.Dispose()
	$cmd = ""
}

function ScalerQuery([string]$cmd) {
	$insert = Connect
		try {
			$insert.CommandText = $cmd
			$success = $insert.ExecuteScalar();
			}
		catch
			{
			"Warning!"
			write-debug "Failed Scaler!!"
			write-debug "Command: $cmd" 
			write-debug "Inserting: $insert"
			write-debug "Reply: $success"
			}
	$insert.Dispose()
	$cmd = ""
}

Function Groupcheck([string]$locname,[string]$appname) {
	$tedoen = $locname + "_APP_" + $appname
	$misschien = $locname + "*" + $appname + "*"
	if(!(Get-ADGroup -Filter "Name -like '$tedoen'" -SearchBase "DC=TMF-Group,DC=COM" | Select Name,DistinguishedName)){
		if(Get-ADGroup -Filter "Name -like '$misschien'" -SearchBase "DC=TMF-Group,DC=COM" | Select Name,DistinguishedName){
			Get-ADGroup -Filter "Name -like '$misschien'" -SearchBase "DC=TMF-Group,DC=COM" | foreach {
				$name = $_.Name
				return "Similair? ->" + $name
			}
		# Option to add/correct?
		} else {
			return "I did not find: $tedoen"
		}
	} else {
		return "Group exist: $tedoen"
	}
}	

function extractMSIinfo ([string]$msilocation){
	Get-MSISummaryInfo "$msilocation" | foreach { 
		if($_.Subject){ 
			$a = $_.Author
			$a= $a.Split(' ')
			$a = $a[0] -replace " ","_"
			$b = $_.Subject
			$b = $b -replace "\.","_"
			$b = $b -replace " ","_"
			$b = $b -replace "\(.*.\)"
			$c = $_.MinimumVersion
			$c = $c -replace "\.","_"
			$sugest = $b + "_" + $c 
			return $sugest
		} 
	}
}

#Check for record in table and column
function checkrecord([string]$record,[string]$table,[string]$column) {
	$insert = Connect
	try {
		$insert.CommandTExt = "SELECT * FROM powershell." + $table + " WHERE " + $column + " LIKE '"+ $record + "'  "
		$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($insert)
		$dataSet = New-Object System.Data.DataSet
		$recordCount = $dataAdapter.Fill($dataSet, "data")
		}
	catch 
		{
		"Something wrong with record check!"
		$insert
		$dataAdapter
		$dataSet
		
		}	
	$insert.Dispose()
	return $recordCount
}

function extractAdvertisement([string]$pkgid) {
	get-sccmadvertisement $server -filter "PackageID='$pkgid'" | foreach {
			#$_.AdvertisementID
			#$_.ProgramName
			$cmd = "UPDATE powershell.cmdlist SET advertis='" + $_.AdvertisementID + "' WHERE pkgid= '" + $pkgid + "' " 
			NonQuery $cmd
			if($_.CollectionID) {
				"Advertisement: " + $_.AdvertisementName + " - ID: " + $_.AdvertisementID
				extractQuery $_.CollectionID $pkgid
			} else {
				#nothing?
			}
		}
}

function extractQuery ([string]$CollectionID,[string]$pkgid) {
	"Checking Group(s)"
	get-sccmobject -sccmserver $server sms_DistributionPoint -filter "PackageID='$pkgid'" | foreach { 
		$sitecode = $_.SiteCode
		get-sccmcollectionrules $server -collectionid "$CollectionID" | foreach { 
			$QueryExpression = $_.QueryExpression
			if ($QueryExpression -Like "*_APP_*") {
				get-sccmsite -sccmserver $server -filter "SiteCode='$sitecode'" | foreach { 
					$ServerName = $_.ServerName
					$ServerName = $ServerName -replace ".SVPS00."
					$QueryExpression = $QueryExpression.Split('\"')
					$cmd = "UPDATE powershell.applist SET adgrp='" + $QueryExpression[3] + "' WHERE pkgid= '" + $pkgid + "' " 
					NonQuery $cmd
					if (!($QueryExpression -like "GRP_APP_*")) {
						"No group checking"
					} else {
						$QueryExpression = $QueryExpression[3] -replace "GRP_APP_"
						$checkgroup = Groupcheck $ServerName $QueryExpression
						"On Distibution Point: $ServerName - $checkgroup"
						$check = checkrecord $ServerName $pkgid "dp"
						if($check -eq 0) {
							$cmd = "INSERT INTO powershell." + $pkgid + " (`pkgid`,` path`, `dp`, `present`) VALUES ('" + $pkgid + "','" + $_.ServerName + "\\SMSPKGD$\\" + $pkgid + "', '" + $ServerName + "','" + $checkgroup + "') ON DUPLICATE KEY UPDATE path = VALUES(path), dp = VALUES(dp), present = VALUES(present)"
							NonQuery $cmd
						} else {
							$cmd = "UPDATE powershell." + $pkgid + " SET pkgid='" + $pkgid + "', path='" + $_.ServerName + "\\SMSPKGD$\\" + $pkgid + "' , present='" + $checkgroup + "' WHERE dp= '" + $ServerName + "' " 
							NonQuery $cmd
						}
					}
				}
			}
		}
	}
}

Function GetProgram([string]$fullpath) {
	# Select a program on PackageID will throw a WMI generic failure?!, so 
	Get-SCCMObject -sccmserver $Server -class SMS_Program | foreach {
			if($_.commandline -like "msiexec*"){ 
				$files = $_.commandline -Split(' ')
				$files = $files -split('"')
				#$doen = $doen -split('_')
				foreach ($file in $files) {
					if($file -like '*.msi') { 
						$msilocation = $fullpath +"\"+ $file
						if(test-path $msilocation) {
							$sugest = extractMSIinfo $msilocation
							# Here is checked what name is better, by reading internally the MSI
							# The code is fine, just not every MSI is correctly setup/named
						} else {
							# Here can come some code that verify is the file was deleted/moved and SCCM is unaware of this.
							$sugest = "Failed"						
						}
						$result = "MSI"
					} elseif ($file -like '*.msp') {
						$result = "Patch"
					}
				}
			}elseif($_.commandline -like "*.exe*"){ 
				$result = "EXE " # + $_.commandline 
			}else{
				$result = "script? " # + $_.commandline
			} 
		$commandline = $_.commandline
		$commandline = $commandline -replace '`\', '`\`\'
		$pkgid = $_.PackageID
		$ProgramName = $_.ProgramName
		if(!($_.comment)) {
			$comment = "Nothing"
		} else {
			$comment = $_.comment
		}
		#$check = checkrecord $pkgid cmdlist pkgid "" #Check for record in table and column
		$insert = Connect
		try {
			$insert.CommandText = "SELECT * FROM cmdlist WHERE PrgName = '"+ $ProgramName +"' AND pkgid = '"+ $pkgid +"' "
			$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($insert)
			$dataSet = New-Object System.Data.DataSet
			$recordCount = $dataAdapter.Fill($dataSet, "data")
			}
		catch 
			{
			"Something wrong with record check!"
			$insert
			$dataAdapter
			$dataSet
			}	
		$insert.Dispose()
		if($recordCount -eq 0) {
			$cmd = "INSERT INTO cmdlist (`pkgid`, ` type`,`cmd`, `PrgName`,`Comments`) VALUES ('" + $pkgid + "','" + $result + "','" + $commandline + "','"+ $ProgramName +"','"+ $Comment +"') ON DUPLICATE KEY UPDATE pkgid = VALUES(pkgid), type = VALUES(type), cmd = VALUES(cmd), PrgName = VALUES(PrgName), Comments = VALUES(Comments)"
			NonQuery $cmd
		} else { 
			$cmd = "UPDATE cmdlist SET type = '"+ $result +"', cmd = '" + $commandline + "' WHERE pkgid = '" + $pkgid + "' AND PrgName ='"+ $ProgramName +"' "
			NonQuery $cmd
		}
		$cmd = "UPDATE applist SET type = '"+ $result +"' WHERE pkgid = '" + $pkgid + "' "
		NonQuery $cmd
	}
}

### Setting up DB ##
	$cmd = "CREATE TABLE applist (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, fullname VARCHAR(100), pkgid VARCHAR(20), pkgver VARCHAR(50), path TEXT, type VARCHAR(50) NOT NULL default 'Package', adgrp VARCHAR(50))";
	ScalerQuery $cmd
	$cmd = "CREATE TABLE cmdlist (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, fullname VARCHAR(100), pkgid VARCHAR(20), cmd TEXT, type VARCHAR(50),advertis VARCHAR(50),PrgName VARCHAR(20),Comments TEXT)";
	ScalerQuery $cmd

### MAIN ###
	
get-sccmsite -sccmserver $server | foreach {
	$cmd = "CREATE TABLE srvlist (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, srvname VARCHAR(20), sitename VARCHAR(50))";
	ScalerQuery $cmd
	$check = checkrecord $_.ServerName srvlist srvname #Check for record in table and column
	if($check -eq 0) {
		$cmd = "INSERT INTO srvlist (`srvname`, `sitename`) VALUES ('" + $_.ServerName + "','" + $_.SiteName + "') ON DUPLICATE KEY UPDATE srvname = VALUES(srvname), sitename = VALUES(sitename)"
		NonQuery $cmd
	} else { 
		$cmd = "UPDATE srvlist SET sitename = '"+ $_.SiteName +"' WHERE srvname = '" + $_.SiteName + "' "
		NonQuery $cmd
	}
}

Get-SCCMPackage $server | foreach { 
	$fullpath = $_.PkgSourcePath
	$pkgid = $_.PackageID
	$name = $_.Name
	$appver = $_.version
	$pkgver = $_.SourceVersion
	if(!($appver)) { $appver = "1" }
	$src = $_.PkgSourcePath -replace '\\', '\\\\'  # Somehow the blackslash keep's messing up
	# First check if record exist!
	$check = checkrecord $pkgid "applist" "pkgid"
	if($check -eq 0) {
		$cmd = "INSERT INTO applist (` fullname`, `pkgid`, `pkgver` , `path`) VALUES ('" + $name + "', '" + $pkgid + "', '" + $pkgver + "' ,'" + $src + "') ON DUPLICATE KEY UPDATE fullname = VALUES(fullname), pkgid = VALUES(pkgid),pkgver = VALUES(pkgver), path = VALUES(path)";
		NonQuery $cmd
	} else {
		$cmd = "UPDATE applist SET fullname='" + $name + "', pkgver='" + $pkgver + "' , path='" + $src + "' WHERE pkgid= '" + $pkgid + "' " 
		NonQuery $cmd
	}
	extractAdvertisement $pkgid
	$check = checkrecord $pkgid "cmdlist" "pkgid"
	if($check -eq 0) {
		$cmd = "INSERT INTO cmdlist (` fullname`, `pkgid`) VALUES ('" + $name + "', '" + $pkgid + "') ON DUPLICATE KEY UPDATE fullname = VALUES(fullname), pkgid = VALUES(pkgid)";
		NonQuery $cmd
	} else {
		$cmd = "UPDATE cmdlist SET fullname='" + $name + "' WHERE pkgid= '" + $pkgid + "' " 
		NonQuery $cmd
	}
	try {
		$cmd = "CREATE TABLE powershell." + $pkgid + " (dp VARCHAR(100) NOT NULL PRIMARY KEY, fullname VARCHAR(100), pkgid VARCHAR(20), pkgver VARCHAR(50), path VARCHAR(200), present VARCHAR(50))";
		ScalerQuery $cmd
		}
	Catch
		{
		#"Already there"
		}
	#$result = GetProgram([string]$pkgid,[string]$fullpath)
	"Package Name: $name - With Package ID: $pkgid "
	"FullPath: $fullpath " 
	$check = checkrecord $Name "applist" "fullname"
	if($check -eq 0) {
		$cmd = "INSERT INTO " + $pkgid + " (` fullname`, `pkgid`, ` pkgver`,` path`) VALUES ('" + $name + "', '" + $pkgid + "', '" + $pkgver + "','" + $src + "') ON DUPLICATE KEY UPDATE fullname = VALUES(fullname), pkgid = VALUES(pkgid), pkgver = VALUES(pkgver), path = VALUES(path)"
		NonQuery $cmd
	} else { 
		$cmd = "UPDATE powershell." + $pkgid + " SET fullname='" + $name + "' , pkgver='" + $pkgver + "' WHERE pkgid='" + $pkgid + "' " 
		NonQuery $cmd
	}
	
	$result = ""
	$sugest = ""
	; ""
} 
GetProgram([string]$fullpath)

### EOF ###
