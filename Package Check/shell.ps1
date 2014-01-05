$Search_Folder = 'C:\Vlad\Github\Daily-Stuff\Package Check\Tests\'

$Search_ContentRegex = ('invalid', 'wrong')
$Search_FilesRegex = ('\.invalid$', '\.valid$')
$Search_ExcludeFiles = ('\.eot$', '\.woff$', '\.xpi$','\.ttf$','\.chm$', '\.exe$', '\.dll$', '\.gif$', '\.png$', '\.jpg$', '\.jpeg$', '\.nupkg$', '\.nuspec$', '\\jquery\.globalize\\cultures\\globalize\.culture\..*\.js$', '\\jquery\.globalize\\cultures\\globalize\.cultures\.js$')

$Result_Template = ((Split-Path $MyInvocation.MyCommand.Path) + '\Common\result_template.html')
$Result_File = ((Split-Path $MyInvocation.MyCommand.Path) + '\result.html')

Add-Type -Language CSharp @"
	public class PackageCheckResult
	{
		public string FileName;
		public int[] LinesNumbers;
		public string[] LinesContent;
		public string[] LinesMatch;
	}
"@;

# Preparing express regex patterns
$Search_ContentRegex_Common = '(?>' + ($Search_ContentRegex -join '|') + ')'
$Search_FilesRegex_Common = '(?>' + ($Search_FilesRegex -join '|') + ')'
$Search_ExcludeFiles_Common = '(?>' + ($Search_ExcludeFiles -join '|') + ')'

# Filling files array
$Search_Folder = $Search_Folder.ToLower()
$TargetFiles = @{}
Get-ChildItem $Search_Folder -Force -Recurse | ?{ !$_.PSIsContainer } | ForEach-Object {
	$fullName = $_.FullName.ToLower()

	if ($_.FullName -notmatch $Search_ExcludeFiles_Common) {
		$key = $fullName.replace($Search_Folder, '\');
		$TargetFiles[$key] = $fullName
	}
}

# Express files check
Write-Host 'Express file extensions check... ' -nonewline
$Express_FileExtensions = $TargetFiles.GetEnumerator() | Where-Object { $_.Value -match $Search_FilesRegex_Common } | Select -uniq -ExpandProperty Key
Write-Host ($Express_FileExtensions.Length.ToString() + ' File(s)')

Write-Host 'Express file names check... ' -nonewline
$Express_FileNames = $TargetFiles.GetEnumerator() | Where-Object { $_.Value -match $Search_ContentRegex_Common } | Select -uniq -ExpandProperty Key
Write-Host ($Express_FileNames.Length.ToString() + ' File(s)')

Write-Host 'Express file content check... ' -nonewline
$Express_FileContent = $TargetFiles.GetEnumerator() | Where-Object { (Get-Content -Path $_.Value) -match $Search_ContentRegex_Common } | Select -uniq -ExpandProperty Key
Write-Host ($Express_FileContent.Length.ToString() + ' File(s)')

# Checking files extensions
Write-Host 'Full file extensions check...'
$Result_FileExtensions = @{}
ForEach ($token in $Search_FilesRegex) {
	$Express_FileExtensions | Where-Object { $_ -match $token } | ForEach-Object {
		if (-not $Result_FileExtensions.ContainsKey($token)) { $Result_FileExtensions[$token] = @() }
		$Result_FileExtensions[$token] += $_
	}
}

# Checking files names
Write-Host 'Full file names check...'
$Result_FileNames = @{}
ForEach ($token in $Search_ContentRegex) {
	$Express_FileNames | Where-Object { $_ -match $token } | ForEach-Object {
		if (-not $Result_FileNames.ContainsKey($token)) { $Result_FileNames[$token] = @() }
		$Result_FileNames[$token] += $_
	}
}

# Checking files content
Write-Host 'Full file content check...'
$Result_FileContent = @{}
ForEach ($token in $Search_ContentRegex) {
	$Express_FileContent | ForEach-Object {
		$resultObj = New-Object PackageCheckResult
		
		$matches = Select-String -Path $TargetFiles[$_] -Pattern $token -AllMatches | Foreach {
			$resultObj.LinesNumbers += $_.LineNumber
			$resultObj.LinesContent += $_.Line
			$resultObj.LinesMatch += $_.Matches
		}

		if ($resultObj.LinesMatch.Length -and $resultObj.LinesMatch.Length.ToString() -ne '0') {
			$resultObj.FileName = $_
			$resultObj.LinesMatch = $resultObj.LinesMatch | Select -uniq

			if (-not $Result_FileContent.ContainsKey($token)) { $Result_FileContent[$token] = @() }
			$Result_FileContent[$token] += $resultObj
		}
	}
}

# Creating result
Copy-Item $Result_Template $Result_File

# Printing files extensions
$TextFileExtension = ''
if ($Search_FilesRegex)
{
	$Search_FilesRegex | ForEach-Object {
		if ($Result_FileExtensions.ContainsKey($_)) {
			$TextFileExtension += ('<div class="pattern error">' + $_ + '</div>')
		}
		else {
			$TextFileExtension += ('<div class="pattern clean">' + $_ + '</div>')
		}
	}
}
	
$TextFileExtensionResults = ''
if ($Result_FileExtensions.GetEnumerator().Length -ne 0)
{
	$Result_FileExtensions.GetEnumerator() | ForEach-Object {
		$key = $_.Key
		$value = $_.Value

		ForEach ($fileName in $value){
			$match = ([regex]$key).Matches($filename) | Select -uniq | Foreach {
				$fileName = $fileName.replace($_, ('<span class="match error">' + $_ + '</span>'))
			}
			$TextFileExtensionResults += ('<p>' + $fileName + '</p>')
		}
	}

	if ($TextFileExtensionResults -ne '') { $TextFileExtensionResults = ('<div class="result-list">' + $TextFileExtensionResults + '</div>') }
}

# Printing files names
$TextDeniedContent = ''
if ($Search_ContentRegex)
{
	$Search_ContentRegex | ForEach-Object {
		if ($Result_FileNames.ContainsKey($_) -or $Result_FileContent.ContainsKey($_)) {
			$TextDeniedContent += ('<div class="pattern error">' + $_ + '</div>')
		}
		else {
			$TextDeniedContent += ('<div class="pattern clean">' + $_ + '</div>')
		}
	}
}

$TextFileNameResult = ''
if ($Result_FileNames.GetEnumerator().Length -ne 0)
{
	$Result_FileNames.GetEnumerator() | ForEach-Object {
		$key = $_.Key
		$value = $_.Value
		
		ForEach ($fileName in $value){
			$match = ([regex]$key).Matches($filename) | Select -uniq | Foreach {
				$fileName = $fileName.replace($_, ('<span class="match error">' + $_ + '</span>'))
			}
			$TextFileNameResult += ('<p>' + $fileName + '</p>')
		}
	}

	if ($TextFileNameResult -ne '') { $TextFileNameResult = ('<div class="result-list">' + $TextFileNameResult + '</div>') }
}

$TextFileContentResult = ''
if ($Result_FileContent.GetEnumerator().Length -ne 0)
{
	$Result_FileContent.GetEnumerator() | ForEach-Object {
		$token = $_.Key
		$obj = $_.Value
		
		if ($obj.Length -ne 0)
		{
			$TextFileContentResult += ('<div class="pattern error">' + $token + '</div>')
		
			$obj | ForEach-Object {	
				$TextFileContentResult += '<div class="result-list-wrapper"><table class="result-list">'
				$TextFileContentResult += ('<tr><th colspan="2">' + $_.FileName + '</th></tr>')
				
				for ($i = 0; $i -le $_.LinesNumbers.Length - 1; $i++) {
					$content = $_.LinesContent[$i]

					$_.LinesMatch | Foreach {
						$content = $content.replace($_, ('<span class="match error">' + $_ + '</span>'))
					}

					$TextFileContentResult += ('<tr><td><div>' + $_.LinesNumbers[$i] + '</div></td><td>' + $content + '</td></tr>')
				}

				$TextFileContentResult += '</table></div>'
			}
		}
	}
}

$cleanText = '<span class="match clean">Everything is clean</span>'

if ($TextFileExtension -eq '') { $TextFileExtension = 'None' }
if ($TextFileExtensionResults -eq '') { $TextFileExtensionResults = $cleanText }

(Get-Content $Result_File) | ForEach-Object { $_ -replace "%FileExtension%", ($TextFileExtension) } | Set-Content $Result_File
(Get-Content $Result_File) | ForEach-Object { $_ -replace "%FileExtensionResults%", ($TextFileExtensionResults) } | Set-Content $Result_File

if ($TextDeniedContent -eq '') { $TextDeniedContent = 'None' }
if ($TextFileNameResult -eq '') { $TextFileNameResult = $cleanText }
if ($TextFileContentResult -eq '') { $TextFileContentResult = $cleanText }

(Get-Content $Result_File) | ForEach-Object { $_ -replace "%DeniedContent%", ($TextDeniedContent) } | Set-Content $Result_File
(Get-Content $Result_File) | ForEach-Object { $_ -replace "%FileNameResult%", ($TextFileNameResult) } | Set-Content $Result_File
(Get-Content $Result_File) | ForEach-Object { $_ -replace "%FileContentResult%", ($TextFileContentResult) } | Set-Content $Result_File