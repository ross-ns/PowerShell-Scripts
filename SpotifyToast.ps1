$toastTemplate  = [Windows.UI.Notifications.ToastTemplateType]::ToastText01
$toastXml       = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($toastTemplate)
$exclusions     = @("Spotify Premium", "DJ X - Up Next") # Window titles / track names not to toast
$nowPlaying     = ""

function GetSpotifyProcess {
    (Get-Process | Where-Object { $_.Name -eq "Spotify" -and $_.MainWindowTitle -ne "" })
}

function MakeToast { 
    param ($currentTrack)

    $textNodes = $toastXml.GetElementsByTagName("text")
    $textNode = $textNodes.Item(0)
    $textNode.InnerText = $currentTrack
    $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Spotify")
    $notifier.Show($toast)   
}

$spotify = GetSpotifyProcess

while ($true) {
    try {
        $currentTrack = (Get-Process -Id $spotify.Id -ErrorAction Stop).MainWindowTitle
    }
    catch {
        do {
            $spotify = GetSpotifyProcess
            Start-Sleep -Seconds 5
        }
        until ($null -ne $spotify)
    }

    if ($currentTrack -ne $nowPlaying -and $exclusions -notcontains $currentTrack) {
        MakeToast $currentTrack
        $nowPlaying = $currentTrack

        Write-Host "Track changed to:" $currentTrack
    }

    Start-Sleep -Seconds 2
}
