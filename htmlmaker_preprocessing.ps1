# Converts a .doc file in bookmaker_tmp to .docx
# you can pass the original file location in convert, but then you have to run tmparchive.rb first
# and of course set the correct location of bookmaker_tmp below
param([string]$inputFile)

# don't forget to set these for your Bookmaker environment!
$logDir="S:\resources\logs\"
# the bookmaker_tmp dir, that is, without the root
$tmpDir="\bookmaker_tmp\" 	

# getting the path inputs
$currVolPath=Get-Location
$currVol=split-path $currVolPath -Qualifier			#C: or S:	
$filenameSplit=split-path $inputFile -Leaf			#file name without path
write-host "Original file is " $filenameSplit
$filename=$filenameSplit.SubString(0, $filenameSplit.LastIndexOf('.')).replace(' ','')	#filename w/out extension or spaces

# define log file
$Logfile =echo $($logDir + $filename + ".txt")

Function LogWrite
{
   Param ([string]$logstring)
   Add-content $Logfile -value "$logstring"
}

# if original file name is a .doc file
$fileType = ".doc"
If ($filenameSplit -eq $filename + $fileType)
{
	# Converts a word .doc in bookmaker_tmp to a .docx
	# so you have to have already run tmparchive.rb
	$folderpath=echo $($currVol + $tmpDir + $filename + "\" + $filename)
	write-host "Converting $filenameSplit to .docx from $fileType..."

	$SaveFormat = "microsoft.office.interop.word.WdSaveFormat" -as [type]
	$word = New-Object -ComObject word.application
	$word.visible = $false

	$doc = $word.documents.open($folderpath + $fileType)
	$wdFormatDocx = 16  # wdFormatDocumentDefault is docx, reference number is 16
	
	# Have to add [ref]s for certain versions of powershell (2.0), we'll see which way works on server
	# https://richardspowershellblog.wordpress.com/2012/10/15/powershell-3-and-word/
	# so only use one or the other of these next two lines
	$doc.saveas($folderpath, $wdFormatDocx)
	#$doc.saveas([ref]$folderpath, [ref]$wdFormatDocx)
	
	$doc.close()
	$word.Quit()
	$word = $null

	# Next line if you want to remove the original .doc file
	# Remove-Item ($folderpath + $fileType)
}

# TESTING

LogWrite "----- DOC-TO-DOCX PROCESSES"

#verify filename is not null
if ($filenameSplit) {LogWrite "pass: original filename is not null"}
Else {LogWrite "FAIL: original filename is not null"}

#filename.docx should exist in tmp conversion dir
$ChkFile = $($currVol + $tmpDir + $filename + "\" + $filename + ".docx")
$FileExists = Test-Path $ChkFile 
If ($FileExists -eq $True) {LogWrite "pass: inputFile.docx exists in $currVol$tmpDir."}
Else {LogWrite "FAIL: inputFile.docx exists in $currVol$tmpDir."}


[gc]::collect()
[gc]::WaitForPendingFinalizers()