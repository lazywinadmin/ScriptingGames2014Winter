function Export-PowerPoint {
		<#
	.SYNOPSIS
	Exports Charts to PowerPoint format

	.DESCRIPTION
	Export the Charts to a powerpoint presentation. The first page is a Title with a subtitle. Then one slide will be created for each graph together with a main title.
	
	.PARAMETER  <Path>
	Specifies de export path folder (must be a folder).
	
	.PARAMETER  <GraphInfos>
	This parameter must be an object with the following two headers : Path;Title.
	Path --> Represents the the path to the physical location of the chart.
	Title --> A short title of what the chart represent
	
	.PARAMETER  <Title>
	Title that will be used on all documents (Front page of the PowerPoint export, Header of Html file). 
	
	.PARAMETER  <Subtitle>
	SubTitle that will be used on all documents (Front page of the PowerPoint export, Header of Html file (Underneath the title)). 
	
	.PARAMETER  <Debug>
	This parameter is optional, and will if called, activate the deubbing mode wich can help to troubleshoot the script if needed. 

	.NOTES
	-Version 0.4
	-Author : Stéphane van Gulick
	-Creation date: 08/01/2014


	.EXAMPLE
	Export-powerPoint -title "PowerShell Winter Scripting Games 2014" -Subtitle "Posh Monks" -Path D:\Exports -GraphInfos $ArrayImage
	
	Exports the Images to a powerPoint format. The file name is Export-PowerShellMonks.pptx. On the first slide,
	The title : "PowerShell Winter Scripting Games 2014" and the subtitle "Power Monks" will be displayed.
	The file will be exported to D:\Export Folder.
	
	

#>
	
	[cmdletbinding()]
	
		Param(
		
		[Parameter(mandatory=$true)]$Path = $(throw "Path is mandatory, please provide a value."),
		[Parameter(mandatory=$true)]$GraphInfos,
		[Parameter(mandatory=$false)]$title,
		[Parameter(mandatory=$false)]$Subtitle
		
		)

	Begin {
		Add-type -AssemblyName office
		Add-Type -AssemblyName microsoft.office.interop.powerpoint
		#DEfining PowerPoints main variables
			$MSTrue=[Microsoft.Office.Core.MsoTriState]::msoTrue
			$MsFalse=[Microsoft.Office.Core.MsoTriState]::msoFalse
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
			[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Titleslide)
		
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
					$slide.Shapes.AddPicture($Graphinfo.Path,$mstrue,$msTrue,300,100,350,400)
					[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($slide)
		}
	}
end {
		$presentation.Saveas($exportPath)
	 	$presentation.Close()
		[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($presentation)
		$Application.quit()
		[System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Application)
		[gc]::collect()
		[gc]::WaitForPendingFinalizers()
		$Application =  $null
	}
	
}
