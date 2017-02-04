#=============================================================
# Script name: build_from_template_csv.ps1
# Version 4.0
# Author: John Lester, Tim Metzger
# I L T
# History:
# 2016-05-13  1.0  Initial Release.
# 2016-06-17  Updated script to now deploy Window VMs
# 2016-09-01  Base line
# 2016-10-11  Screen output organization
# 2016-12-09  Providing credentials to Connect-ViServer
#=============================================================
#	LOCATION OF ADDITIONAL COMPONENTS
#-------------------------------------------------------------
	Write-Host "Adding VMware Snapin" -ForegroundColor Cyan
	Add-PSSnapin VMware.* -ErrorAction SilentlyContinue
#=============================================================
#	FUNCTIONS
#=============================================================
FUNCTION LOGIT($var0, $var1){
	$DateStamp = Get-Date -Format g
	IF ($var0 -eq "title"){$decoration = "WHITE";$tab = "[$DateStamp] "}#TITLE
	ElseIF ($var0 -eq "action"){$decoration = "CYAN";$tab = "[$DateStamp]     "}#ACTION
	ElseIF ($var0 -eq "success"){$decoration = "GREEN";$tab = "[$DateStamp]          "}#SUCCESS
	ElseIF ($var0 -eq "fail"){$decoration = "RED";$tab = "[$DateStamp]          "}#FAIL
	ElseIF ($var0 -eq "information"){$decoration = "GRAY";$tab = "[$DateStamp]     "}#INFORMATIONAL
	ElseIF ($var0 -eq "warning"){$decoration = "YELLOW";$tab = "[$DateStamp]     "}#WARNING
	Else {$decoration = "";$tab = "$DateStamp"}#OTHER
	
	#Add-Content -Path $LogFilePath -value "$tab$var1"
	Write-Host "$tab$var1" -ForegroundColor $decoration
	}
#===============================================================
Function ConnectToServer($ViServer) {
	$Error.Clear()
	$ExecutionUser = [Environment]::UserName
	LOGIT warning "Make sure VPN is connected before proceeding..."
	LOGIT action "Username: $ExecutionUser"
	LOGIT action "VIServer: $ViServer"
	$ConnectionSuccess = Connect-ViServer -Server $ViServer -User insertuserhere -Password insertpasswordhere -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
	If ($Error.Count -gt 0) {
		LOGIT fail "Unable to connect to $ViServer"
		exit
		}
	}
#=============================================================
Function SetupLogFile($LogFileVar) {
	$LogFile = $LogFileVar.substring(2)
	$LogFile = $LogFile.TrimEnd(".csv")
	$global:LogFilePath = "$pwd\$LogFile.log"
	
	If (Test-Path ($LogFilePath)) {
		#Remove-Item $LogFilePath
		#...decided to simply append to existing if exists.
		}
	LOGIT title "***** Log file started *****"
	}
#===============================================================
Function ConnectionTest {
	if ($global:DefaultVIServers.Count -gt 1) {
		LOGIT fail "Connected to too many VIServers."
		exit
		}
	if ($global:DefaultVIServers.Count -lt 1) {
		LOGIT fail "Not connected to any VIServers."
		exit
		}
	}
#===============================================================
Function ImportList($ListImport) {
	$global:ImportData = Import-Csv $ListImport
	}
#===============================================================
Function GetRecordContent ($LineData) {
	$boolContinue = $true
	
	LOGIT action "Validate line entry for processing"
	If ($LineData -eq $null) {
		LOGIT warning "INVALID LINE: NULL"
		$boolContinue = $false
		}
	
	If ($boolContinue -eq $true) {
		Set-Variable CLUSTER $LineData.cluster -Scope Global
		$ClusterValidation = Get-Cluster -Name $CLUSTER -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
		If ($ClusterValidation -eq $null) {
			LOGIT warning "INVALID CLUSTER: $CLUSTER"
			$boolContinue = $false
			}
		}
	
	If ($boolContinue -eq $true) {
		Set-Variable TEMPLATE $LineData.template -Scope Global
		Set-Variable vmname $LineData.name -Scope Global
		Set-Variable CLUSTER $LineData.cluster -Scope Global
		Set-Variable TIER $LineData.tier -Scope Global
		Set-Variable NOTE $LineData.notes -Scope Global
		Set-Variable CPUS $LineData.cpu -Scope Global
		Set-Variable MEM $LineData.mem -Scope Global
		Set-Variable DISK $LineData.disk -Scope Global
		LOGIT title "[IMPORT: Line:$Record]"
		LOGIT action "Importing server build CSV file"
		LOGIT information "TEMPLATE: $template"
		LOGIT information "NAME:     $vmname"
		LOGIT information "CLUSTER:  $cluster"
		LOGIT information "TIER:     $tier"
		LOGIT information "NOTES:    $note"
		LOGIT information "CPUs:     $cpus"
		LOGIT information "MEM:      $mem"
		LOGIT information "DISK:     $disk"
		Set-variable nts "Created with $template template. $note"
		$LOC = $vmname.substring(0,2)
		$TYPE = $vmname.substring(5,1)
		Set-Variable LOC $loc.toupper() -Scope Global
		Set-Variable TYPE $type.toupper() -Scope Global
		#ClusterWork
		ManifestWork
		}
	}
#===============================================================
Function ClusterWork {
	If ($boolContinue -eq $true) {
		LOGIT title "[CLUSTER]"
		if (Get-Cluster -name $CLUSTER) {
			LOGIT success "CONFIRMED: $CLUSTER is valid."
			NetworkWork
			}
		else {
			LOGIT warning "WARNING: $CLUSTER not found, skipping to next VM."
			continue
			}
		}
	}
#===============================================================
Function NetworkWork {
	If ($boolContinue -eq $true) {
		LOGIT title "[NETWORK]"
		Try {
			LOGIT action "Checking DNS for $vmname"
			#$([system.net.dns]::GetHostAddresses("$vmname").IPAddressToString)
			$global:ip = [system.net.dns]::GetHostAddresses("$vmname").IPAddressToString
			LOGIT success "CONFIRMED: $vmname in DNS ($ip)"
			$global:gateway = %{$ips = $ip.Split("{.}");"$($ips[0]).$($ips[1]).$($ips[2]).1"}
			$global:netname = %{$ips = $ip.Split("{.}");"$($ips[0]).$($ips[1]).$($ips[2]).0"}
			CustomSpecFileWork
			}
		Catch {
			LOGIT fail "FAILED: $vmname is not in DNS"
			continue
			}
		
		}
	}
#===============================================================
Function CustomSpecFileWork {
	If ($boolContinue -eq $true) {
		LOGIT title "[CUSTOMIZATION SPEC FILE]"
		$Error.Clear()
		
		if ($TYPE -eq "w") {
			$CustomSpecFile = "Static_Windows_Server"
			LOGIT action "Checking for custom spec file: [Custom_$vmname]"
			$CustomizationSpecFile = Get-OSCustomizationSpec Custom_$vmname -ErrorAction SilentlyContinue
			If ($CustomizationSpecFile.count -gt 0){
				LOGIT success "CONFIRMED: ALREADY BUILT."
				}
			Else {
				$StaticSpecFile = Get-OSCustomizationSpec $CustomSpecFile -ErrorAction SilentlyContinue
				If ($StaticSpecFile -eq $null) {
					LOGIT fail "No Static Spec file exists."
					DisconnectFromServer
					}
				Else {
					LOGIT information "Not found."
					LOGIT action "Replicating custom spec file: [$CustomSpecFile] as [Custom_$vmname]"
					Get-OSCustomizationSpec $CustomSpecFile | New-OSCustomizationSpec -Name Custom_$vmname | Out-Null
					Set-OSCustomizationSpec -Description "$vmname custom spec" -OSCustomizationSpec custom_$vmname | Out-Null
					$Nicmap=Get-OSCustomizationSpec custom_$vmname | Get-OSCustomizationNicMapping
					LOGIT action "Setting DNS entries in Custom_$vmname"
					Set-OSCustomizationNicMapping -OSCustomizationNicMapping $Nicmap -IpAddress $ip -IpMode UseStaticIP -dns 172.17.17.17 -DefaultGateway $gateway -SubnetMask 255.255.255.0 | Out-Null
					LOGIT success "CONFIRMED: custom_$vmname"
					}
				}
			}
		else {
			$CustomSpecFile = "Static_customspec"
			LOGIT action "Checking for custom spec file: [Custom_$vmname]"
			$CustomizationSpecFile = Get-OSCustomizationSpec Custom_$vmname -ErrorAction SilentlyContinue
			If ($CustomizationSpecFile.count -gt 0){
				LOGIT success "CONFIRMED: ALREADY BUILT."
				}
			Else {
				$StaticSpecFile = Get-OSCustomizationSpec $CustomSpecFile -ErrorAction SilentlyContinue
				If ($StaticSpecFile -eq $null) {
					LOGIT fail "No Static Spec file exists."
					DisconnectFromServer
					}
				Else {
					LOGIT information "Not found."
					LOGIT action "Replicating custom spec file: $CustomSpecFile as Custom_$vmname"
					Get-OSCustomizationSpec $CustomSpecFile | New-OSCustomizationSpec -Name Custom_$vmname | Out-Null
					Set-OSCustomizationSpec -Description "$vmname custom spec" -OSCustomizationSpec custom_$vmname | Out-Null
					LOGIT action "Setting DNS entries in Custom_$vmname"
					$Nicmap=Get-OSCustomizationSpec custom_$vmname | Get-OSCustomizationNicMapping
					LOGIT information "Nicmap = $Nicmap"
					LOGIT information "ip = $ip"
					LOGIT information "gateway = $gateway"
					Set-OSCustomizationNicMapping -OSCustomizationNicMapping $Nicmap -IpAddress $ip -IpMode UseStaticIP -DefaultGateway $gateway -SubnetMask 255.255.255.0 | Out-Null
					LOGIT success "CONFIRMED: custom_$vmname"
					}
				}
			}
		DatastoreWork
		}
	}
#===============================================================
Function DatastoreWork {
	If ($boolContinue -eq $true) {
		$global:LargestFreeSpace = "0"
		LOGIT title "[DATASTORE]"
		LOGIT action "Inpecting cluster location."
		# VCPROD
		if ($global:DefaultVIServers.name  -contains "vcprod") {
			if ($CLUSTER -like "TIER*") {
				$ClusterLocation = "Tier"
				}
			else {
				$FoundCtr = "0"
				$MetroCheck = Get-Cluster -location metro
				ForEach ($MetroCluster in $MetroCheck) {
					If ($MetroCluster.name -eq $CLUSTER) {
						$FoundCtr = $FoundCtr + 1
						}
					}
				If ($FoundCtr -eq "1") {	
					$ClusterLocation = "Metro"
					}	
				else {
					$ClusterLocation = "Other"
					}
				}
			}
		# VCCERT
		else {
			$ClusterLocation = "Other"
			}
		LOGIT action "Get-VMHost ($CLUSTER)"
		$VMHosts = Get-VMHost -location $CLUSTER | Sort-Object name
		$FirstHost = $VMHosts[0]
		LOGIT action "Get-Datastore ($FirstHost)" 
		
		#Scan Appropriate datastore
		If ($ClusterLocation -eq "Tier") {$datastores = $FirstHost | Get-Datastore -name ${LOC}*_VPLEX_Tier_${TIER}_VM_0* -refresh}
		If ($ClusterLocation -eq "Tier") {$datastores = $FirstHost | Get-Datastore -name ${LOC}*_VM_* -refresh}
		If ($ClusterLocation -eq "Other") {$datastores = $FirstHost | Get-Datastore -name *VM* -refresh}
		
		$DatastoresSorted = $datastores | Sort-Object FreeSpaceGB -Descending
		ForEach ($datastore in $DatastoresSorted) {
			$DatastoreName = @($datastore | select -exp name)
			$DatastoreFreeSpace = @($datastore | select -exp FreeSpaceGB)
			$DatastoreFreeSpace = "{0:N2}" -f $DatastoreFreeSpace
			}
		$global:LargestDatastore = $DatastoresSorted[0].name
		$LargestFreeSpace = $DatastoresSorted[0].FreeSpaceGB
			$LargestFreeSpace = "{0:N0}" -f $LargestFreeSpace
			If ($DISK -eq "none") {
				$RequiredSpace = 64
				}
			Else {
				$RequiredSpace = 64 + $DISK
				}
		$DriveSizeValidation = $LargestFreeSpace - $RequiredSpace
		
		If ($DriveSizeValidation -gt 0) {
			LOGIT success "CONFIRMED: datastore [$LargestDatastore] with $LargestFreeSpace GB free space."
			ManifestWork
			}
		Else {
			LOGIT fail "FAILED: NOT ENOUGH SPACE IN DATASTORE"
			DisconnectFromServer
			LOGIT title "***** Log file ended *****"
			exit
			}
		}
	}
#===============================================================
Function ManifestWork {
	If ($boolContinue -eq $true) {
		LOGIT title "[COMPILED BUILD MANIFEST]"
		LOGIT information "ServerName:  $vmname"
		LOGIT information "Template:    $template"
		LOGIT information "Cluster:     $CLUSTER"
		LOGIT information "Datastore:   $LargestDatastore"
		LOGIT information "Netname:     $netname"
		LOGIT information "Cores:       $CPUS"
		LOGIT information "Memory:      $MEM"
		LOGIT information "App Drive:   $DISK"
		LOGIT information "IP Address:  $IP"
		LOGIT information "Tier:        $TIER"
		LOGIT information "Note:        $nts"
		#BuildVM
		Get-VM -Name $vmname | Stop-VMGuest -Confirm:$false
		#Remove existing VMGuest from Inventory
		#Stop-VMGuest -VM $vmname -Confirm:$false
		sleep -s 15
		Remove-VM -DeletePermanently -VM $vmname -Confirm:$false
		}
	}
#===============================================================
Function BuildVM {
	If ($boolContinue -eq $true) {
		#-------------------------------------------------------------
		# Execute Compiled Setup Command
		#-------------------------------------------------------------
		LOGIT title "[EXECUTE BUILD]"
		LOGIT action "Creating new VM...."
		New-vm -name $vmname -resourcepool $CLUSTER -datastore $largestdatastore -Notes $nts -OScustomizationSpec custom_$vmname -Template $TEMPLATE| Out-Null
		remove-oscustomizationspec custom_$vmname -confirm:$false
		LOGIT action "Checking if additional space requested."
		# Add Hard Disk Space
		if ($DISK -eq "none") {
			LOGIT information "No extra disk space required"
			}
		else {
			LOGIT action "Adding second Hard disk with size of $DISK GB."
			if ($TYPE -eq "w") {
				get-harddisk -vm $vmname -name "Hard Disk 2" | set-harddisk -capacityGB $DISK -confirm:$false -WarningAction SilentlyContinue | Out-Null
				}
			else {
				new-harddisk -vm $vmname -capacityGB $DISK -Persistence persistent | Out-Null
				}
			}
		#-------------------------------------------------------------
		# Configure: Networking
		#-------------------------------------------------------------
		LOGIT action "Configuring VLAN"
		$net = get-vm -name $vmname | get-networkadapter -Name "Network adapter 1"
		Set-networkAdapter -NetworkAdapter $net -networkname $netname -confirm:$false | Out-Null

		#-------------------------------------------------------------
		# Configure: CPU Core and Socket
		#-------------------------------------------------------------
		LOGIT action "Configuring CPU and RAM"
		set-vm -vm $vmname -name $vmname  -NumCPU $cpus -MemoryGB $mem   -confirm:$false | Out-Null

		$vcores = New-Object -Type VMware.Vim.VirtualMachineConfigSpec -Property @{"NumCoresPerSocket" = $CPUS }
		(Get-VM $vmname).ExtensionData.ReconfigVM_Task($vcores) | Out-Null
		
		#-------------------------------------------------------------
		# Configure: VMWare Tools settings
		#-------------------------------------------------------------
		LOGIT action "Configuring VMware Tools"
		$vm = get-vm $vmname | Get-View
		$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
		$vmConfigSpec.Tools = New-Object VMware.Vim.ToolsConfigInfo
		$vmConfigSpec.Tools.ToolsUpgradePolicy = "upgradeAtPowerCycle"
		$vm.ReconfigVM($vmConfigSpec)

		
		if ($global:DefaultVIServers.name  -contains "vcprod") {
			LOGIT information "You are connected to VCPROD"
			LOGIT action "Checking for Metro and Tierred-apps."

			#Add Tier annotation to VM
			set-Annotation -Entity $vmname -CustomAttribute "Tier Level" $tier | Out-Null

			if ($CLUSTER -like "TIER*") {
				#-------------------------------------------------------------
				# Configure: Tiered Apps (Add to correct DRS VM Group)
				#-------------------------------------------------------------
				$DRSGRP = get-drsvmgroup -cluster $cluster -name ${LOC}*Tier*${TIER}*Guest* | select -ExpandProperty name
				LOGIT action "Adding $vmname to the DRS Virtual Machine DRS Group - $DRSGRP - for cluster $CLUSTER."
				get-drsvmgroup -cluster $cluster -name $DRSGRP |  set-drsvmgroup -append -vm $vmname | Out-Null
				LOGIT action "Correcting name to match Tierred-apps naming convention."
				if ($CLUSTER -like "*CENT*") {
					set-vm -vm $vmname -name ${vmname}-T${TIER}-Cent -confirm:$false | Out-Null
					LOGIT action "Powering on VM at $(get-date)." -ForegroundColor black
					start-vm -vm ${vmname}-T${TIER}-Cent -confirm:$false | Out-Null
					continue
					}
				if ($CLUSTER -like "*RHEL*") {
					set-vm -vm $vmname -name ${vmname}-T${TIER}-RHEL -confirm:$false | Out-Null
					LOGIT action "Powering on VM at $(get-date)."
					start-vm -vm ${vmname}-T${TIER}-RHEL -confirm:$false | Out-Null
					continue
					}
				if ($CLUSTER -like "*WINDOWS*") {
					set-vm -vm $vmname -name ${vmname}-T${TIER} -confirm:$false | Out-Null
					LOGIT action "Powering on VM at $(get-date)."
					start-vm -vm ${vmname}-T${TIER} -confirm:$false | Out-Null
					continue
					}
				}
			else {
				#-------------------------------------------------------------
				# Configure: Non-Tiered Apps (Add to correct DRS VM Group)
				#-------------------------------------------------------------
				$FoundCtr = "0"
				ForEach ($MetroCluster in $MetroCheck) {
					If ($MetroCluster.name -eq $CLUSTER) {
						$FoundCtr = $FoundCtr + 1
						}
					}
				If ($FoundCtr -eq "1") {
					$DRSGRP = Get-DRSVMGroup -cluster $cluster -name ${LOC}*Guest* | select -ExpandProperty name
					LOGIT action "Adding $vmname to the DRS Virtual Machine DRS Group - $DRSGRP - for cluster $CLUSTER."
					get-drsvmgroup -cluster $cluster -name $DRSGRP |  set-drsvmgroup -append -vm $vmname | Out-Null
					}
				Else {
					LOGIT information "$CLUSTER does not exist in METRO."
					}
				}
			}
		#-------------------------------------------------------------
		# POWER-ON VIRTUAL MACHINE
		#-------------------------------------------------------------.
		LOGIT action "Powering on VM at $(get-date)."
		start-vm -vm ${vmname} -confirm:$false | Out-Null
		}
	}
#=============================================================
Function DisconnectFromServer {
	$ViAccounts = Get-VIAccount
	ForEach ($ViAccount in $ViAccounts) {
		$ViServer = $ViAccount.server
		}
	LOGIT title "-------------------------------------------------------------"
	LOGIT action "Disconnecting from $ViServer..."
	Disconnect-ViServer -Server $ViServer -confirm:$false
	LOGIT success "done."
	$DateStamp = Get-Date -Format g
	LOGIT title "***** Log file ended *****"
	exit
	}
#=============================================================
#	MAIN
#=============================================================
	Clear-Host
	If ($args.Length -lt 2) {
		Clear-Host
		Write-Host "=============================================" -ForegroundColor Yellow -BackgroundColor Black
		Write-Host "****** OOPS ****** UH-OH ****** WHIFF ******" -ForegroundColor Yellow -BackgroundColor Black
		Write-Host "=============================================" -ForegroundColor Yellow -BackgroundColor Black
		Write-Host ""
		Write-Host "     USAGE: Build.ps1 Answerfile.csv VCCERT" -ForegroundColor White -BackgroundColor Black
		Write-Host ""
		Write-Host " example:" -ForegroundColor Cyan -BackgroundColor Black
		Write-Host "     Builder.ps1 ProjectName_Cert.csv VCCERT" -ForegroundColor White -BackgroundColor Black
		Write-Host ""
		Write-Host ""
		Write-Host ""
		Write-Host ""
		}
	Else {
		$MyCSVFile = ($args[0])
		$ViServer = ($args[1])
		
		#SetupLogFile ($MyCSVFile)
		if(!($global:DefaultVIServer)) {ConnectToServer ($ViServer)}
		ConnectionTest
		ImportList ($MyCSVFile)
		
		[int]$Record = 0
		foreach ($line in $ImportData) {
			$elapsedTime = [System.Diagnostics.Stopwatch]::StartNew()
			$Record = $Record + 1
			GetRecordContent ($line)
			LOGIT success ("Elapsed Time : {0}" -f $($elapsedTime.Elapsed.ToString()))
			LOGIT title "============================================================="
			}
		DisconnectFromServer
		}

