Winter Scripting Games 2014
========================

**TEAM: POSH Monks**

We are a team of six people participating to the Winter Scripting Games 2014 (PowerShell Script language).
This repository is holding our team work accomplished during each events.



Team
-------

### Team members

* Francois-Xavier Cat (Canada GMT -5:00) [@LazyWinAdm](https://twitter.com/LazyWinAdm) - [Blog](http://lazywinadmin.com)
* Stephane Van Gulick (Switzerland GMT+1:00) [@Stephanevg](https://twitter.com/Stephanevg) - [Blog](http://powershelldistrict.com)
* Deepak Dhami (India GMT+5:30) [@DexterPOSH](https://twitter.com/DexterPOSH) - [Blog](http://dexterposh.blogspot.ca/)
* Allister Philippe (France GMT+1:00)
* Benjamin Rouleau (France GMT+1:00)
* Guido Oliviera (Brazil GMT -2:00) [@_Guido_Oliveira](https://twitter.com/_Guido_Oliveira) - [Blog](http://guidooliveira.com/)


### Working Together

##### For each scenario we should proceed the following way

1. Analyze the scenario/requirements and establish a plan/strategy (CF Event0-Strategy.md)
2. Create the script structure (Think about the performance impact, Error handling, loop,...)
3. Split the work if possible (Sections, differents functions...)
4. Assign one person to post the script regularly to get input from Coaches

##### Additionally we should meet on Google Hangout or take advantage of

* Github issue tracking
* Discussion forum of our team in scriptinggames.org





Scripting Games
-------

### General Information
* [Winter Scripting Games 2014 Players Guide](http://scriptinggames.org/games/2014WinterSGPlayersGuide.pdf)

### Script Milestones

1. Milestone 1: Make the script work
2. Milestone 2: Performance
3. Test and Test and Test

### PowerShell Best Practices
From the ebook "PowerShell.org Pratices" (nov 2013)

* Error handling
* Comment based help
  * Describe each parameter
  * Provide usage examples
  * Use the Notes Section for detail on how the tool works
  * Keep your language simple
* Comment your inline code
  * Keep it simple
  * Don't over comment
* Versioning
  * Write for the lowest version of PowerShell that you can
  * Document the version of PowerShell the script was written for (#requires)
* Performance
  * If performance matters, test it
  * consider trade-offs between performance and readability
* Aesthetics
  * Indent your code
  * Avoid Backtick
* Output
  * Avoid write-host unless writing to the host is the only goal
  * Use write-verbose to give information to someone running the script
  * Use write-debug to give information to someone maintaining the script
  * Use [Cmdletbinding()] if you are using verbose and debug
* Tools vs Controller
  * Decide whether you're coding a tool (reusable tool(s)) or controller script (one purpose, not really reusable)
  * Make your code modular
  * Make tools as re-usable as possible
  * Use PowerShell standard cmdlet naming
  * Use PowerShell standard parameter naming
  * Tools should output raw data
  * Contollers script should typically output formatted data
* Purity laws
  * Use native powershell where possible
  * If you can't use PowerShell, use .NET, external commands, COM objects,...
  * Document why you did not use PowerShell
  * Wrap other tools in an advanced function of cmdlet
* Pipelines vs Constructs
  * Avoir using pipelines in scripts
* Trapping and Capturing Errors
  * Use -ErrorAction Stop when calling cmdlets
  * Use $ErrorActionPreference='Stop'/'Continue' when calling cmdlets
  * Avoid using Flags to handle errors
  * Avoir using $?
  * Avoid testing for a null variable as an error condition
  * Copy $Error[0] to your own variable
* Wasted Effort
  * Don’t re-invent the wheel
  * Report bugs to Microsoft





## Events Information


#### EVENT 0 - PRACTICE EVENT

##### Dates
* Instruction available: 2014/01/01 00:00 UTC
* Entries accepted starting: 2014/01/06 00:00 UTC
* All entries due by: 2014/01/12 00:00 UTC
* Public browsing of entries starts: 2014/01/12 00:00 UTC
* Judging completed by: 2014/01/18 00:00 UTC

#### EVENT 1 - PAIRS

##### Dates
* Instruction available: 2014/01/18 00:00 UTC
* Entries accepted starting: 2014/01/19 00:00 UTC
* All entries due by: 2014/01/26 00:00 UTC
* Public browsing of entries starts: 2014/01/26 00:00 UTC
* Judging completed by: 2014/02/01 00:00 UTC

#### EVENT 2 - SECURITY FOOTPRINT

##### Dates
* Instruction available: 2014/01/25 00:00 UTC
* Entries accepted starting: 2014/01/26 00:00 UTC
* All entries due by: 2014/02/02 00:00 UTC
* Public browsing of entries starts: 2014/02/02 00:00 UTC
* Judging completed by: 2014/02/08 00:00 UTC

#### EVENT 3 - ACL CACL TOIL AND TROUBLE

##### Dates
* Instruction available: 2014/02/01 00:00 UTC
* Entries accepted starting: 2014/02/02 00:00 UTC
* All entries due by: 2014/02/09 00:00 UTC
* Public browsing of entries starts: 2014/02/09 00:00 UTC
* Judging completed by: 2014/02/15 00:00 UTC


#### EVENT 4 - MONITORING SUPPORT

##### Dates
* Instruction available: 2014/02/08 00:00 UTC
* Entries accepted starting: 2014/02/09 00:00 UTC
* All entries due by: 2014/02/16 00:00 UTC
* Public browsing of entries starts: 2014/02/16 00:00 UTC
* Judging completed by: 2014/02/22 00:00 UTC


Useful links
-------

* [ScriptingGames.org](http://ScriptingGames.org)
* [PowerShell.org - Scripting Games Posts](http://powershell.org/wp/category/announcements/scripting-games/)
* [PowerShell.org - Great Debate](http://powershell.org/wp/category/great-debates/)
* [PowerShell.org - Free Ebooks](http://powershell.org/wp/newsletter/)
* [PowerShell.com - Ebooks](http://powershell.com/cs/media/28/default.aspx)
* [GitHub Markdown Cheatsheet](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)
* [GitImmersion.com](http://gitimmersion.com)
