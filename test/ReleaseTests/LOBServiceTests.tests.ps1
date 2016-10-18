Param (
	[string] $ServiceUrl = $env:Custom_ServiceUrl
)

Write-Host "Runnning tests $ServiceUrl..."

function GetPage {
	Invoke-WebRequest -Uri "http://$ServiceUrl" -UseBasicParsing -TimeoutSec 5
}

Describe "LOB Service Availability" {
	$response = GetPage

	It "Runs CGI" {
		$response.Content | Should Match "application"
	}

	It "Runs Service" {
		$response.Content | Should Match "Back-end"
	}
}

Describe "Windows Service Functionality" {
	It "Runs Service" {
		$response1 = GetPage
		Start-Sleep 1
		$response2 = GetPage
		$response1.Content | Should Not Be $response2.Content
	}
}