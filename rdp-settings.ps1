# RDP Settings GUI Manager (Save as rdp-settings-gui.ps1)

# Check for administrator privileges
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object Security.Principal.WindowsPrincipal $user;
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch as administrator if needed
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow
    Write-Host "Attempting to relaunch with administrator privileges..." -ForegroundColor Yellow
    
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
    }
    catch {
        Write-Host "Failed to restart with administrator privileges. Please run this script as administrator." -ForegroundColor Red
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        exit
    }
    
    exit
}

Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="RDP Settings Manager" Height="600" Width="800"
    WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="100"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <TextBlock Grid.Row="0" Text="Remote Desktop Protocol Settings Manager" 
                   FontSize="20" FontWeight="Bold" Margin="0,0,0,10"/>

        <!-- Settings ScrollViewer -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
            <StackPanel>
                <!-- Display Settings -->
                <GroupBox Header="Display Settings" Margin="0,5,0,10">
                    <StackPanel Margin="5">
                        <TextBlock Text="Refresh Rate:" Margin="0,5"/>
                        <ComboBox x:Name="RefreshRateCombo" Margin="0,5" SelectedIndex="0">
                            <ComboBoxItem Content="System Default"/>
                            <ComboBoxItem Content="30Hz"/>
                            <ComboBoxItem Content="60Hz"/>
                            <ComboBoxItem Content="120Hz"/>
                            <ComboBoxItem Content="144Hz"/>
                        </ComboBox>
                    </StackPanel>
                </GroupBox>

                <!-- Graphics Settings -->
                <GroupBox Header="Graphics Settings" Margin="0,5,0,10">
                    <StackPanel Margin="5">
                        <CheckBox x:Name="UseHardwareGraphics" Content="Use hardware graphics adapters for all Remote Desktop Services sessions" 
                                 Margin="0,5"/>
                        <CheckBox x:Name="PrioritizeAVC444" Content="Prioritize H.264/AVC 444 graphics mode" 
                                 Margin="0,5"/>
                        <CheckBox x:Name="EnableHardwareEncoding" Content="Enable H.264/AVC hardware encoding" 
                                 Margin="0,5"/>
                        <CheckBox x:Name="DisableWDDM" Content="Disable WDDM graphics display driver" 
                                 Margin="0,5"/>
                    </StackPanel>
                </GroupBox>
            </StackPanel>
        </ScrollViewer>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10">
            <Button x:Name="ApplyButton" Content="Apply Settings" Padding="20,5" Margin="5,0"/>
            <Button x:Name="RefreshButton" Content="Refresh Status" Padding="20,5" Margin="5,0"/>
        </StackPanel>

        <!-- Status Box -->
        <GroupBox Grid.Row="3" Header="Status">
            <TextBox x:Name="StatusText" IsReadOnly="True" TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto"/>
        </GroupBox>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get controls
$refreshRateCombo = $window.FindName("RefreshRateCombo")
$useHardwareGraphics = $window.FindName("UseHardwareGraphics")
$prioritizeAVC444 = $window.FindName("PrioritizeAVC444")
$enableHardwareEncoding = $window.FindName("EnableHardwareEncoding")
$disableWDDM = $window.FindName("DisableWDDM")
$applyButton = $window.FindName("ApplyButton")
$refreshButton = $window.FindName("RefreshButton")
$statusText = $window.FindName("StatusText")

# Helper function to add status message
function Add-Status {
    param($Message, [bool]$IsError = $false)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $statusText.AppendText("[$timestamp] $Message`r`n")
    $statusText.ScrollToEnd()
}

# Helper function to get current settings
function Get-CurrentSettings {
    try {
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
        $refreshPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations"

        # Get current refresh rate
        $currentRefreshRate = Get-ItemProperty -Path $refreshPath -Name "DWMFRAMEINTERVAL" -ErrorAction SilentlyContinue
        
        # Get current graphics settings
        $hwGraphics = (Get-ItemProperty -Path $policyPath -Name "bEnumerateHWBeforeSW" -ErrorAction SilentlyContinue).bEnumerateHWBeforeSW
        $avc444 = (Get-ItemProperty -Path $policyPath -Name "AVC444ModePreferred" -ErrorAction SilentlyContinue).AVC444ModePreferred
        $hwEncode = (Get-ItemProperty -Path $policyPath -Name "AVCHardwareEncodePreferred" -ErrorAction SilentlyContinue).AVCHardwareEncodePreferred
        $wddm = (Get-ItemProperty -Path $policyPath -Name "fEnableWddmDriver" -ErrorAction SilentlyContinue).fEnableWddmDriver

        # Update UI
        $useHardwareGraphics.IsChecked = $hwGraphics -eq 1
        $prioritizeAVC444.IsChecked = $avc444 -eq 1
        $enableHardwareEncoding.IsChecked = $hwEncode -eq 1
        $disableWDDM.IsChecked = $wddm -eq 0

        Add-Status "Current settings loaded successfully"
    }
    catch {
        Add-Status "Error loading current settings: $_" -IsError $true
    }
}

# Apply Button Click
$applyButton.Add_Click({
    try {
        $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
        
        # Apply refresh rate
        $refreshPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations"
        switch ($refreshRateCombo.SelectedIndex) {
            0 { Remove-ItemProperty -Path $refreshPath -Name "DWMFRAMEINTERVAL" -ErrorAction SilentlyContinue }
            1 { Set-ItemProperty -Path $refreshPath -Name "DWMFRAMEINTERVAL" -Value 30 -Type DWord }
            2 { Set-ItemProperty -Path $refreshPath -Name "DWMFRAMEINTERVAL" -Value 15 -Type DWord }
            3 { Set-ItemProperty -Path $refreshPath -Name "DWMFRAMEINTERVAL" -Value 8 -Type DWord }
            4 { Set-ItemProperty -Path $refreshPath -Name "DWMFRAMEINTERVAL" -Value 6 -Type DWord }
        }

        # Apply graphics settings
        Set-ItemProperty -Path $policyPath -Name "bEnumerateHWBeforeSW" -Value ([int]$useHardwareGraphics.IsChecked) -Type DWord
        Set-ItemProperty -Path $policyPath -Name "AVC444ModePreferred" -Value ([int]$prioritizeAVC444.IsChecked) -Type DWord
        Set-ItemProperty -Path $policyPath -Name "AVCHardwareEncodePreferred" -Value ([int]$enableHardwareEncoding.IsChecked) -Type DWord
        Set-ItemProperty -Path $policyPath -Name "fEnableWddmDriver" -Value ([int](!$disableWDDM.IsChecked)) -Type DWord

        Add-Status "Settings applied successfully"
    }
    catch {
        Add-Status "Error applying settings: $_" -IsError $true
    }
})

# Refresh Button Click
$refreshButton.Add_Click({
    Get-CurrentSettings
})

# Initial load of current settings
Get-CurrentSettings

# Show the window
$window.ShowDialog() | Out-Null 
