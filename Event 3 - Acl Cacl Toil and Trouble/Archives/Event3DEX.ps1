Function Test-FolderStructure
{
<#(Only useful if we use the OutPutXMLConfiguration parameter)
Generate a psobject
Parameter: -Path
Parameter: -OutputXMLConfiguration (generate xml config output of the ACL, this can be reused with Set-FolderStructurePermission)
	Validate: Test-Path
#>
	 [CmdletBinding()]
	PARAM(
		[Parameter(Mandatory)]
		[ValidateScript({Test-Path -Path $_ -PathType Container})]
		$DepartmentRootFolder,

		
	)#PARAM
	BEGIN
	{
		Write-Verbose -Message "[BEGIN] Starting the Function"
        #$defaultNamingContext=([ADSI]"LDAP://rootDSE").defaultNamingContext 
                
	}#BEGIN Block
	PROCESS
	{
		TRY{
            #First verify if the Group exists in the Domain with the same name...
            $Filter = "(&(ObjectCategory=group)(Name=$(Split-Path -Path $DepartmentRootFolder -Leaf)))"
            $Searcher = New-Object System.DirectoryServices.DirectorySearcher($Filter)
            
            if ($group = $Searcher.FindOne())
            {
                #Group exists
                Write-Verbose -message "[PROCESS] $(split-path -Path  $DepartmenRootFolder -Leaf) Folder and corresponding AD Group exists"
                $foldersinRoot = Get-ChildItem -Path $DepartmentRootFolder -Directory 

                #member Group names
                $GroupMembers = foreach ($member in $group.Properties.member)
                {
                    (($member -split ",")[0] -split "=")[1]
                }
                
                foreach ($folder in $foldersinRoot)
                {
                     #now folders in root can be named after the Team names (which are nested in the Department AD Group  or a Department_Open folder
                     
                     if ($folder.name -eq "$(Split-Path -Path $DepartmentRootFolder -Leaf)_Open")
                     {
                        #Folder of type Department_Open
                     }
                     elseif ($GroupMembers -contains $folder.name )
                     {
                        #Folder which matches the name of nested Groups inside Department
                        $TeamGroup = ([adsisearcher]"(&(ObjectCategory=group)(Name=$($Folder.name)))").FindOne()
                         Get-ChildItem -Path $folder.FullName -Directory | ForEach-Object -Process {
                            switch  -exact ($_.name) 
                            {
                                "$Folder_Shared" {Write-Verbose -Message "$Folder_Shared exists"}
                                "$Folder_Private" { Write-Verbose -Message "$Folder_Private Exists"; break}
                                "$Folder_Lead" 
                                { 
                                    if ($TeamGroup.Properties.Member -match "$folder_Lead") 
                                    {
                                        Write-Verbose -Message "$Folder_Lead exists"
                                    } 
                                    else 
                                    {
                                        Write-Warning "$Folder_Lead Folder exists but corresponding AD group doesn't"
                                    }
                                }
                                default {Write-Warning -Message "$_.name not as per standards"}
                            }
                        }
                     }
                     else
                     {
                        #Doesn't match criteria
                        Write-Warning "$Folder.name is not per the Standards"
                     }
                }
            }
            else
            {
                #group doesn't exist in AD
            }
            }#TRY Block
		CATCH{
			Write-Warning -Message "[PROCESS] Something went wrong !"
			Write-Warning -Message $Error[0]
		}#CATCH Block	
	}#PROCESS Block
	END
	{
		TRY{}#TRY Block
		CATCH{}#CATCH Block	
	}#END Block
}#Function Get-FolderStructure


