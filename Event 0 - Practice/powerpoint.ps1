#========================================================================
# Created with: SAPIEN Technologies, Inc., PowerShell Studio 2012 v3.1.21
# Created on:   1/8/2014 7:35 PM
# Created by:   Administrator
# Organization: 
# Filename:     
#========================================================================

#MSDN help articles

#Shapes: http://msdn.microsoft.com/en-us/library/office/bb265573(v=office.12).aspx

function ExportTo-PowerPoint {
		<#
	.SYNOPSIS
	Exports Charts to PowerPoint format

	.DESCRIPTION
	Export the graphs to a powerpoint presentation.
	
	.PARAMETER  <ExportPath>
	Specifies de export path (must be have either .ppt or pptx as extension).
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed. 

	.NOTES
	-Version 0.1
	-Author : Stéphane van Gulick
	-Creation date: 01/06/2012
	-Creation date: 01/06/2012
	-Script revision history
	##0.1 : Initilisation
	##0.2 : First version
	##0.3 : Added Image possibilities

	.EXAMPLE
	Exportto-html -Data (Get-Process) -Path "d:\temp\export.html" -title "Data export"
	
	Exports data to a HTML file located in d:\temp\export.html with a title "Data export"
	
	.EXAMPLE
	In order to call the script in debugging mode
	Exportto-html  -Image $ByteImage -Data (Get-service) "d:\temp\export.html" -title "Data Service export"
	
	Exports data to a HTML file located in d:\temp\export.html with a title "Data export". Adds also an image in the HTML output.
	#Remark: -image must be  of Byte format.
	.LINK
	#PowerPoint ComObject main help page
		http://msdn.microsoft.com/en-us/library/aa189759(v%3Doffice.10).aspx
	#Create a SlideShow
		http://msdn.microsoft.com/en-us/library/office/aa220415(v=office.11).aspx
	#Shapes
		#Shape help
			http://msdn.microsoft.com/en-us/library/office/bb265573(v=office.12).aspx
		#Adding Shapes to slides
			http://msdn.microsoft.com/en-us/library/aa163597(v=office.10).aspx
		#Text in a shape
			http://msdn.microsoft.com/en-us/library/aa189295(v=office.10).aspx
		#Working with shapes on slides
			http://msdn.microsoft.com/en-us/library/aa141428(v=office.10).aspx
		#Adding picture to Shapes
		http://msdn.microsoft.com/en-us/library/office/bb230700(v=office.12).aspx
	#Interesting office com object examples (powerpoint 3rd example)
		http://www.autohotkey.com/board/topic/56987-com-object-reference-autohotkey-l/page-4
	#Scripting guy basic information
		http://blogs.technet.com/b/heyscriptingguy/archive/2010/05/12/hey-scripting-guy-can-i-add-a-new-slide-to-an-existing-microsoft-powerpoint-presentation.aspx
	#Maybe solution for Byteimage
		http://msdn.microsoft.com/en-us/library/office/bb251372(v=office.12).aspx
#>
	
	[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$ExportPath = $(throw "Path is mandatory, please provide a value."),
		[Parameter(mandatory=$true)]$GraphInfos,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle
		
		)

	Begin {
		Add-type -AssemblyName office

		#DEfining PowerPoints main variables
			$MSTrue=[Microsoft.Office.Core.MsoTriState]::msoTrue
			$MsFalse=[Microsoft.Office.Core.MsoTriState]::msoFalse
		#http://msdn.microsoft.com/en-us/library/microsoft.office.interop.powerpoint.ppslidelayout(v=office.14).aspx
			$slideTypeTitle = [microsoft.office.interop.powerpoint.ppSlideLayout]::ppLayoutTitle
			$SlideTypeChart = [microsoft.office.interop.powerpoint.ppSlideLayout]::ppLayoutChart
			
		#Creating the ComObject
			$Application = New-Object -ComObject powerpoint.application
			#$application.visible = $MSTrue
	}
	Process{
		#Creating the presentation
			$Presentation = $Application.Presentations.add() 
		#Adding the first slide
			$Titleslide = $Presentation.Slides.add(1,$slideTypeTitle)
			$Titleslide.Shapes.Title.TextFrame.TextRange.Text = $Title
			$Titleslide.shapes.item(2).TextFrame.TextRange.Text = $Subtitle
			$Titleslide.BackgroundStyle = 11

		#Adding the charts
		foreach ($Graphinfo in $GraphInfos) {

			#Adding slide
			$slide = $Presentation.Slides.add($Presentation.Slides.count+1,$SlideTypeChart)

			#Defining slide type:
			#http://msdn.microsoft.com/en-us/library/microsoft.office.interop.powerpoint.ppslidelayout(v=office.14).aspx
					$slide.Layout = $SlideTypeChart
					$slide.BackgroundStyle = 11
					$slide.Shapes.Title.TextFrame.TextRange.Text = $Graphinfo.title
			#Adding picture (chart) to presentation:
				#http://msdn.microsoft.com/en-us/library/office/bb230700(v=office.12).aspx
					$Picture = $slide.Shapes.AddPicture($Graphinfo.Path,$mstrue,$msTrue,300,100,350,400)
		}
	}
end {
		$presentation.Saveas($exportPath)
	 	$presentation.Close()
		$Application.quit()
		[gc]::collect()
		[gc]::WaitForPendingFinalizers()
		$Application =  $null
	}
	
}

#$b= Get-Base64Image "E:\Users\Administrator\Pictures\Pepe-thumbs-up.jpg"

$a=@()
$obj1 = [pscustomobject]@{Path="E:\Users\Administrator\Pictures\Pepe-thumbs-up.jpg"; Title="Pepe ze Praawn !!"}
$a += $obj1 
$obj2 = [pscustomobject]@{Path="E:\Users\Administrator\Pictures\vlcsnap-2013-08-20-23h52m03s141.png"; Title="Woopy di woof!!"}
$a += $obj2

ExportTo-PowerPoint -ExportPath "D:\temp\plop.pptx" -GraphInfos $a -title "PowerShell Monks" -Subtitle "Event 00 - Practice"