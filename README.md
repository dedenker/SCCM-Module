SCCM-Module
===========
Here a scripts that some depend on "SCCM-Commands.psm1" (see below for details).
The purpose is to extent the funtionally and flexiblity of SCCM 2007 and 2012.

Examples:
readvertisement.ps1           Recreate an package and advertisement, so already deployed clients get an updated source.
object-location.ps1           Locates an object in the SCCM console
invertory.ps1                 Creates an invertory in MySQL for web control (still under development)
ADgrp_Collection.ps1          verifies if the groups collection have corrisponding AD groups

Regarding SCCM-Commands.psm1:
  SCCM powershell Module 3.0

  Created by : Stephane van Gulick (@stephanevg)
  Website : www.PowerShellDistrict.com

  The SCCM PowerShell module version 3.0 contains today 79 cmdlets for managing the SCCM 2007 infrastructure whith PowerShell (through WMI).

  Since WMI is still the underlying technology used by SCCM 2012, a great part of the cmdlets (or logic) can be re-used for   SCCM 2012 management.
  And will be extended to 2012, at the moment making sure all needed functions are present.
  Then start working on a 2012 version.

  The module is provided "AS IS", use at your own risk.

