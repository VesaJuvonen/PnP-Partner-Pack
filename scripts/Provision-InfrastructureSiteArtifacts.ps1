﻿<#
.SYNOPSIS
Provisions required artifacts to the Infrastructure Site

.EXAMPLE
PS C:\> .\Provision-InfrastructureSiteArtifacts.ps1 -InfastructureSiteUrl "https://mytenant.sharepoint.com/sites/infrastructure"

.EXAMPLE
PS C:\> $creds = Get-Credential
PS C:\>.\Provision-InfrastructureSiteArtifacts.ps1 -InfastructureSiteUrl "https://mytenant.sharepoint.com/sites/infrastructure" -Credentials $creds

#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true, HelpMessage="The URL of your infrastructure site, e.g. https://mytenant.sharepoint.com/sites/infrastructure")]
    [String]
    $InfrastructureSiteUrl,

    [Parameter(Mandatory = $true, HelpMessage="The URL of your Azure Web site")]
    [String]
    $AzureWebSiteUrl,

	[Parameter(Mandatory = $false, HelpMessage="Optional tenant administration credentials")]
	[PSCredential]
	$Credentials

)


# DO NOT MODIFY BELOW
$basePath = "$(convert-path ..)\OfficeDevPnP.PartnerPack.SiteProvisioning\OfficeDevPnP.PartnerPack.SiteProvisioning"

# Modify Responsive design template to include Azure WebSite Url
$responsiveTemplate = (Get-Content "$basePath\Templates\Responsive\SPO-Responsive.xml") -As [Xml]
$parameter = $responsiveTemplate.Provisioning.Preferences.Parameters.Parameter | ?{$_.Key -eq "AzureWebSiteUrl"}
$parameter.InnerText = $AzureWebSiteUrl.Trim('/')
$responsiveTemplate.Save("$basePath\Templates\Responsive\SPO-Responsive.xml");

# Modify PnP Partner Pack Overrides template to include Azure WebSite Url
$responsiveTemplate = (Get-Content "$basePath\Templates\Overrides\PnP-Partner-Pack-Overrides.xml") -As [Xml]
$parameter = $responsiveTemplate.Provisioning.Preferences.Parameters.Parameter | ?{$_.Key -eq "AzureWebSiteUrl"}
$parameter.InnerText = $AzureWebSiteUrl.Trim('/')
$responsiveTemplate.Save("$basePath\Templates\Overrides\PnP-Partner-Pack-Overrides.xml");

if($Credentials -eq $null)
{
	$Credentials = Get-Credential -Message "Enter Tenant Admin Credentials"
}

$InfrastructureSiteUrl = $InfrastructureSiteUrl.Trim('/')
$uri = [System.Uri]$InfrastructureSiteUrl

$siteHost = $uri.Host.ToLower()
$siteHost = $siteHost.Replace(".sharepoint.com","-admin.sharepoint.com")
$siteHost = $siteHost.Trim('/')

Connect-SPOnline -Url "https://$siteHost" -Credentials $Credentials
$infrastructureSiteInfo = Get-SPOTenantSite -Url $InfrastructureSiteUrl -ErrorAction SilentlyContinue
if($InfrastructureSiteInfo -eq $null)
{
    Write-Host -ForegroundColor Cyan "Infrastructure Site does not exist. Please create site collection first through the UI, or use New-SPOTenantSite"
} else {
    Connect-SPOnline -Url $InfrastructureSiteUrl -Credentials $Credentials
    Apply-SPOProvisioningTemplate -Path "$basePath\Templates\Infrastructure\PnP-Partner-Pack-Infrastructure-Jobs.xml"
    Apply-SPOProvisioningTemplate -Path "$basePath\Templates\Infrastructure\PnP-Partner-Pack-Infrastructure-Templates.xml"

    # Unhide the 2 infrastructure lists
    $l = Get-SPOList "PnPProvisioningTemplates"
    $l.Hidden = $false
    $l.OnQuickLaunch = $true
    $l.Update()
    Execute-SPOQuery

    $l = Get-SPOList "PnPPRovisioningJobs"
    $l.Hidden = $false
    $l.OnQuickLaunch = $true
    $l.Update()
    Execute-SPOQuery
    
	Apply-SPOProvisioningTemplate $basePath\Templates\PnP-Partner-Pack-Infrastructure-Contents.xml
}