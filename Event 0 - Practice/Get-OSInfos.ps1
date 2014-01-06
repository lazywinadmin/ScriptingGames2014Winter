Function Get-OSInfo
{
   param 
   (
   [parameter(Mandatory=$true)]
   [String]$IPAddress,
   [String]$Reachable
   	)

   $ComputerInfos = Get-WmiObject Win32_OperatingSystem -ComputerName $IPAddress
   
   $CustomObj = New-Object PSObject
   $CustomObj | Add-Member	NoteProperty IPAdress $IPAddress
   $CustomObj | Add-Member	NoteProperty ComputerName $ComputerInfos.csname
   $CustomObj | Add-Member	NoteProperty OS $ComputerInfos.caption
   $CustomObj | Add-Member	NoteProperty ServicePack $ComputerInfos.csdversion
   $CustomObj | Add-Member	NoteProperty Reachable $Reachable
   
   $CustomObj | Export-Csv test.csv -NoTypeInformation -Delimiter ";"
  
                                    
}
