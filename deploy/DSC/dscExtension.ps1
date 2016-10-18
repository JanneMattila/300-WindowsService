Configuration DeployLOBApplication
{
    Param (
        [Parameter(Mandatory=$true)][string] $nodeName, 
        [Parameter(Mandatory=$true)][string] $applicationPackage)

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $nodeName
    {
        WindowsFeature WebServerRole
        {
            Name = "Web-Server"
            Ensure = "Present"
        }

        WindowsFeature WebCGI
        {
            Name = "Web-CGI"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]WebServerRole"
        }

        WindowsFeature WebISAPIExt
        {
            Name = "Web-ISAPI-Ext"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]WebServerRole"
        }
    
        Script DeployCGIApplication
        {
            DependsOn = "[WindowsFeature]WebCGI" 

            GetScript = {
                @{
                    Result = ""
                }
            }

            TestScript = {
                $false
            }

            SetScript = {
                #
                # If you need to "wipe out" extension then you can do that with following command:
                # Remove-AzureRmVMDscExtension -VMName lobserver1 -ResourceGroupName "legacyservice-local-rg" -verbose -Name "DscExtension"
                # More info: 
                # https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-extensions-troubleshoot/#troubleshooting-extenson-failures
                # 

                # If you don't believe that this is really executed on the server then modify this :):
                Write-Output "ApplicationPackage 1.0: $($using:applicationPackage)" >> c:\WindowsAzure\log.txt

                Import-Module IISAdministration
                $sm = Get-IISServerManager
                $hostConfig = $sm.GetApplicationHostConfiguration()
                $isapiCgiRestriction = $hostConfig.GetSection("system.webServer/security/isapiCgiRestriction")
                $isapiCgiRestrictionCollection = $isapiCgiRestriction.GetCollection()
                if ($isapiCgiRestrictionCollection.Count -eq 0)
                {
                    # More information:
                    # https://www.iis.net/configreference/system.webserver/security/isapicgirestriction/add
                    $isapiCgiRestrictionCollectionElement = $isapiCgiRestrictionCollection.CreateElement("add")
                    $isapiCgiRestrictionCollectionElement.Attributes["path"].Value = "C:\inetpub\wwwroot\LOBCGI.exe"
                    $isapiCgiRestrictionCollectionElement.Attributes["allowed"].Value = $true
                    $isapiCgiRestrictionCollectionElement.Attributes["description"].Value = "LOB CGI"
                    $isapiCgiRestrictionCollection.Add($isapiCgiRestrictionCollectionElement)

                    $sm.CommitChanges()
                }
            
                $hostConfig = $sm.GetApplicationHostConfiguration()
                $handlersSection = $hostConfig.GetSection("system.webServer/handlers")
                $handlersCollection = $handlersSection.GetCollection()
                $handlersCollection["accessPolicy"] = "Read,Execute"

                if ($handlersCollection[0]["name"] -ne "LOBCGI")
                {
                    # More information:
                    # https://www.iis.net/configreference/system.webserver/handlers/add
                    $addElement = $handlersCollection.CreateElement("add")
                    $addElement.Attributes["name"].Value = "LOBCGI"
                    $addElement.Attributes["path"].Value = "*.*"
                    $addElement.Attributes["verb"].Value = "GET,HEAD,POST"
                    $addElement.Attributes["modules"].Value = "CgiModule"
                    $addElement.Attributes["scriptProcessor"].Value = "C:\inetpub\wwwroot\LOBCGI.exe"
                    $addElement.Attributes["resourceType"].Value = "Either"
                    $addElement.Attributes["requireAccess"].Value = 4 # "Execute"
                    $handlersCollection.AddAt(0, $addElement)

                    $sm.CommitChanges()
                }

                $webConfig = $sm.GetWebConfiguration("Default Web Site")

                # More information:
                # https://www.iis.net/configreference/system.webserver/defaultdocument
                $defaultDocumentSection  = $webConfig.GetSection("system.webServer/defaultDocument")
                $defaultDocumentSection["enabled"] = $true
                $defaultDocumentCollection = $defaultDocumentSection.GetCollection("files")
                $defaultDocumentCollection.Clear()
                $addElement = $defaultDocumentCollection.CreateElement("add")
                $addElement["value"] = "LOBCGI.exe"
                $defaultDocumentCollection.AddAt(0, $addElement)

                $sm.CommitChanges()

                $destination = "C:\WindowsAzure\LOBApplication.zip"

                # Download our application package
                Invoke-WebRequest $using:applicationPackage -OutFile $destination

                # Exctract Zip package to local folder
                Expand-Archive -Force -LiteralPath $destination -DestinationPath "C:\WindowsAzure\LOBApplication"

                $serviceNotInstalled = ((Get-Service -Name "LOBService" -ErrorAction SilentlyContinue) -eq $null)
                if ($serviceNotInstalled)
                {
                    # Service is not deployed so let's create folder where running service will be stored
                    New-Item -Path "C:\WindowsAzure\LOBService" -Force -ItemType Directory
                }
                else
                {
                    # Service is deployed
                    Stop-Service -Name "LOBService" -Force
                }

                # Copy our applications to correct locations
                Copy-Item -Path "C:\WindowsAzure\LOBApplication\App\LOBCGI.exe" -Destination "C:\inetpub\wwwroot\" -Force
                Copy-Item -Path "C:\WindowsAzure\LOBApplication\App\LOBService.exe" -Destination "C:\WindowsAzure\LOBService\" -Force

                if ($serviceNotInstalled)
                {
                    New-Service -Name "LOBService" -BinaryPathName "C:\WindowsAzure\LOBService\LOBService.exe"
                }

                Start-Service -Name "LOBService"
            }
        }
    }
}
