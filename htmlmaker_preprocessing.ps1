# Converts a .doc file in bookmaker_tmp to .docx, and removes any
# revision info in the XML file for .docx if you have "Store random numbers
# to improve Combine accuracy" unchecked already.
# you can pass the original file location in convert,
# but you have to run tmparchive.rb first
# and of course set the correct location of log dir and bookmaker_tmp below

param([string]$inputFile)

# don't forget to set these for your Bookmaker environment!
$logDir="S:/resources/logs/"
# the bookmaker_tmp dir without the root or trailing slash
$tmpDir="/bookmaker_tmp"

# getting the path inputs
#$currVolPath=Get-Location
$currVol='S:'#split-path $currVolPath -Qualifier	#C: or S:
$filenameSplit=split-path $inputFile -Leaf			#file name without path
$uniqueTmpDir=split-path(split-path $inputFile -Parent) -Leaf
Write-Host "Input file is $filenameSplit"
$filename=$filenameSplit.SubString(0, $filenameSplit.LastIndexOf('.')).replace(' ','')	#filename w/out extension or spaces
$fileType=$filenameSplit.SubString($filenameSplit.LastIndexOf('.'))  # just extension
$subfolder=$inputFile -match "(?:bookmaker\w+)(?<imprint>/.+?/)"    # regex to match level that follow 'bookmaker' or 'bookmaker_tmp', incl leading and training backslash
$imprintPath=$matches["imprint"]                             # returns match from previous line

# put it all together for tmp path
$folderpath=echo $($currVol + $tmpDir + $imprintPath + $uniqueTmpDir + "/")
$docpath=echo $($folderpath + $filename)  #with doc name, w/o extension

# define log file
$Logfile =echo $($logDir + $filename + ".txt")

Function LogWrite
{
   Param ([string]$logstring)
   Add-content $Logfile -value "$logstring"
}

# Converts a word .doc in bookmaker_tmp to a .docx
# so you have to have already run tmparchive.rb
If ($fileType -like ".doc")
{
 write-host "Converting $filenameSplit to .docx from $fileType"
}

$SaveFormat = "microsoft.office.interop.word.WdSaveFormat" -as [type]
$word = New-Object -ComObject word.application
$word.visible = $false

# Make sure "Store random number..." setting is off
$word.Options.StoreRSIDOnSave = $false
Write-Host "Removing revision data"

$doc = $word.documents.open($docpath + $fileType)

# turn off track changes, accept all changes and delete all comments
# have to do here, or we don't solve dumb XML revision problem
$doc.TrackRevisions = $false
$doc.Revisions.AcceptAll()
Foreach($comment in $doc.Comments)
{
    $comment.Delete()
}

# save file as .docx
# If we didn't make changes we still need to force save, so we can
# remove any revision data in XML file, so set 'Saved' property to false
$doc.Saved=$false
$wdFormatDocx = 16  # wdFormatDocumentDefault is docx, reference number is 16

# Have to add [ref]s for certain versions of powershell (2.0),
# we'll see which way works on server
# https://richardspowershellblog.wordpress.com/2012/10/15/powershell-3-and-word/
# so only use one or the other of these next two lines
$saved=$doc.Saved
#$doc.saveas($docpath, $wdFormatDocx)
$doc.saveas([ref]$docpath, [ref]$wdFormatDocx)

$doc.close()
$word.Quit()
$word = $null

# Next line if you want to remove the original .doc file
# Remove-Item ($folderpath + $fileType)

# TESTING

LogWrite "----- HTMLMAKER-PREPROCESSING PROCESSES"

# verify filename is not null
if ($filenameSplit) {LogWrite "pass: original filename is not null"}
Else {LogWrite "FAIL: original filename is not null"}

# filename.docx should exist in tmp conversion dir
$ChkFile = $($docpath + ".docx")
$FileExists = Test-Path $ChkFile
If ($FileExists -eq $True) {LogWrite "pass: $filename.docx exists in $folderpath"}
Else {LogWrite "FAIL: $filename.docx exists in $folderpath"}

# all done
LogWrite "finished htmlmaker-preprocessing"

[gc]::collect()
[gc]::WaitForPendingFinalizers()
