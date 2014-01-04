Event 0 - Practice Event
========================

TEAM: POSH Monks

Strategy
-------

### Requirements of the Scenario

1. Subnet IP Scanner
  * IP found associated with Machine ? (return Operating System, Service Pack)
  * Result Negative or Positive should be kept for future use in CSV preferably (other readable format accepted, XML?)
2. Set of Data: Investigate specific Machines/Group of Machines (!!! The set of data to be returned should be selectable!!!)
  * Hardware Information
    * Manufacturer, 
    * Model, 
    * cpu, 
    * ram, 
    * disk sizes (only local disks are required).
  * Date of last hotfix applied (Get-Hotfix)
  * Last Reboot Time (human readable)
  * The Following Installed ?
    * IIS (present ? $true or $false)
    * SQL Server (present ? $true or $false)
    * Exchange (present ? $true or $false)
    * Sharepoint (present ? $true or $false)
  * Installed Windows Components
  * Other requirements for this set of data
    * Set of data to be returned should be selectable
    * Data need to be saved for future use
      * FileName should include the date of production of the information and to be descriptive of their content
  * ASSUME
    * You have permissions to access all the machines on the network
    * All required firewall ports are open
  * Ability to choose your preferred access mechanism and retrieve the required data in another way (Example: Different protocols like CIM, WMI, PSRemoting...)
3. Able to take a file of fata and produce a report including graphical representation of the data where possible (example chart of OS... SP .... SQL installed on all machines)
4. The Code should be production ready with:
  * Ability to optionally report on progress (Verbose I guess...)
  * Full Error checking, reporting and handling (write-warning/error...TRY and CATCH)
  * Ability to accept pipeline input where appropriate 
  * Help is available
  * Input Validated
5. Additionally
  * Code should be expandable if we want to add properties
  * Entry should include a transcript of the script running in a PowerShell window
 
  
### Key Criteria

Judges will look at the following points

  * Consider the practices in The Community Book of PowerShell Practices (linked at http://powershell.org/wp/newsletter)
  * Avoid aliases, except for –Object cmdlets; avoid positional parameters and truncated parameter names.
  * Use appropriate error handling.
  * Use appropriate means of displaying output, progress messages, errors, etc.
  * When appropriate, manage pipeline input correctly
  * When appropriate, validate input via parameter validation attributes
  * Provide help for all scripts and functions, including examples
  * Script filenames should include production date for versioning
  * Use modular programming practices to maximize opportunities to share code
  * Use appropriate remote connectivity protocol(s), including, where appropriate, failover to backup protocols
  * Produce appropriate CSV file for initial scan; other formats including XML are permitted.
  * Input is subnet, not a range
  * Report includes IP addresses with no response as well as responses
  * Service pack reported (or report no service pack)
  * Investigative routines can accept input from pipeline, or single machines
  * Investigative routines are modular, which may include them being separate scripts
  * Graphical reports available
  * PowerPoint file including graphs is produced

As is often the case in Windows PowerShell, there will be many ways to complete these objectives. In most cases, judges will prefer approaches that:
  * Perform well under the load specified
  * Leverage built-in functionality of Windows PowerShell rather than reinventing the wheel
  * Are the most straightforward and easy to read and understand


### Analyze

We decided to split the work in three parts
-Scanning IP
-Gathering Information
-Reporting Information


### Workflow

Note: these following parts are not the actual function names, just for representation purposes.



#### SCAN-SUBNET
**Assignees**: Deepak and Allister

**Using Get-Inventory, It should returns**:
* Objects and send it to the next cmdlets
* A csv file (Format example: 10.0.0.0_24-20140104_153905.csv)
 
**Using just the function Scan-Subnet, It should returns**:
* A csv file (Format example: 10.0.0.0_24-20140104_153905.csv)




#### GATHER-INFORMATION
**Assignees**: Francois-Xavier and Guido

**Using Get-Inventory, It should returns**:
* Objects and send it to the next cmdlets
* A csv file (Format example: Inventory-SERVER01-20140104_153905.csv)
 
**Using just the function Gather-Information, It should returns**:
* A csv file (Format example: Inventory-SERVER01-20140104_153905.csv)




#### REPORT-INFORMATION
**Assignees**: Stephane and Benjamin

**Using Get-Inventory, It should returns**:
* A csv file (Format example: Report-SERVER01-20140104_153905.csv)
 
**Using just the function Gather-Information, It should returns**:
* A csv file (Format example: Report-SERVER01-20140104_153905.csv)

##### FINAL SCRIPT

We will deliver only one PS1 file to the judge
This file will contains the following part:
-Scan-Subnet
-Gather-Information
-Report-Information
-Get-Inventory: Final part that call all the functions (Scan | Gather | Report)


