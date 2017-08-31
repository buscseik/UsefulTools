function Set-TimeStampPrompt        
{ 
<#
   
.DESCRIPTION
   This function will add time stamp to current console prompt.

.EXAMPLE
   DateEcho "This message need a timesamp"
   26.01.2017-22:24:08> This message need a timesamp

.EXAMPLE
    Set-TimeStampPrompt   

    PS  [08/31/2017 12:20:09] C:\Users\>

.EXAMPLE
    Set-TimeStampPrompt -disable   

    PS  C:\Users\>

#>
    param([switch]$disable=$false)
    if(-not $disable)
    {   
        function global:Prompt {        
            "PS "+ " [$(Get-Date)] " + $(get-location) +"> "            
        }
    }
    else
    {
        function global:Prompt {
            "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) ";
            # .Link
            # https://go.microsoft.com/fwlink/?LinkID=225750
            # .ExternalHelp System.Management.Automation.dll-help.xml
        }
    }
}

function DateEcho($Var)
{
<#
   
.DESCRIPTION
   This function will add an extra time stamp for all input.
   Pipeline enabled command.

.EXAMPLE
   DateEcho "This message need a timesamp"
   26.01.2017-22:24:08> This message need a timesamp

.EXAMPLE
    ping 8.8.8.8 -t | DateEcho   

    26.01.2017-22:24:48> Reply from 8.8.8.8: bytes=32 time=10ms TTL=57
    26.01.2017-22:24:49> Reply from 8.8.8.8: bytes=32 time=13ms TTL=57
    26.01.2017-22:24:50> Reply from 8.8.8.8: bytes=32 time=12ms TTL=57
    26.01.2017-22:24:51> Reply from 8.8.8.8: bytes=32 time=10ms TTL=57
    26.01.2017-22:24:52> Reply from 8.8.8.8: bytes=32 time=10ms TTL=57
#>
    
    process
    {
         $TimeStamp=Get-Date -Format "dd.MM.yyyy-HH:mm:ss> "
        "$TimeStamp$Var$_"
        
    }
    

}

function Get-UpTimeStatistics
{
#System can start or stop
#Start event can be InstanceID 1 or 2147489653
#Stop event can be InstanceID  41 or 2147489654
#need to find each start stop pair and caculat a difference and sum it.

#Additional: Log the first start and last stop event and caculate as total

#If system shutdown unexpected, two start log will follow each other
#log the last proceed event log, if both was start event,
#than check previous log for last online state and handle as a start stop pair

<#
   
.DESCRIPTION
   This function Will list all system up-time related events and calculate a usage statistics based on these event logs.
       

   

.EXAMPLE
    Get-UpTimeStatistics
    
    ...
    Sytem Wake up at :07/09/2017 13:57:02 - Sleep at: 07/09/2017 16:59:43 | Total uptime: 10961(3:2:41)
    Sytem Wake up at :07/09/2017 18:57:33 - Sleep at: 07/09/2017 22:50:31 | Total uptime: 13978(3:52:58)
    Sytem Wake up at :07/09/2017 23:00:24 - Sleep at: 07/09/2017 23:21:41 | Total uptime: 1277(0:21:17)
    Sytem Wake up at :07/10/2017 07:53:26 - Sleep at: 07/10/2017 07:54:34 | Total uptime: 68(0:1:8)
    Sytem Wake up at :07/10/2017 07:54:50 - Sleep at: 07/10/2017 07:54:59 | Total uptime: 9(0:0:9)
    Sytem Wake up at :07/10/2017 09:05:35 - Sleep at: 07/10/2017 11:30:12 | Total uptime: 8677(2:24:37)

    Total Uptime: 815631(9 Day, 10:33:51)

    Total time: 2351273(27 Day, 5:7:53)

    Uptime Percent: 34.6889110707264

#>



$var=Get-EventLog -LogName system -InstanceId 42
$var+=Get-EventLog -LogName system -InstanceId 1 -Source Microsoft-Windows-Power-Troubleshooter
$var+=Get-EventLog -LogName system -Source EventLog | where Message -match ".*started|stopped.*"
$var= $var | sort Index

#clear-host
$var
"`n"
$wakeUpTime=$null;
$totalUpTime=0;
$FirstWakUpTime=0
$LastSleepTime=0
$LastEventType="stopped"
$LastEvent=$null
foreach($next in $var)
{
    #sleep or shutdown event
    if($next.InstanceID -eq 42 -or $next.InstanceId -eq 2147489654)
    {
        #check if there was any wakeuptime event already proceed.
        if($wakeUpTime -ne $null)
        {
            #calculate elapsed time between start and stop event
            $uptime=($next.TimeGenerated-$wakeUpTime).TotalSeconds
            $TimeSpan=New-TimeSpan -Seconds $uptime

            #Log information to display
            "Sytem Wake up at :" + $wakeUpTime + " - Sleep at: " + $next.TimeGenerated + " | Total uptime: " + $uptime+"("+$TimeSpan.Hours.ToString()+":"+$TimeSpan.Minutes.ToString()+":"+$TimeSpan.Seconds.ToString()+")"
            
            #Add currnet uptime to total
            $totalUpTime+=$uptime

            #save last sleep time for total time calculation
            $LastSleepTime=$next.TimeGenerated

            #save eventtype
            $LastEventType="stopped"
        }
    }
    
    
    #Wake Up event
    if($next.InstanceID -eq 1 -or $next.InstanceId -eq 2147489653)#wakupEvent
    {
        #This required to monitor previous monitored event was start or stopped type, 
        #if previous was start than there was an unexpected shutdown, and need to check last recorded online state on EventLog source.
        if($LastEventType -eq "started" -and $lastEvent.InstanceID -eq 2147489653)
        {
            #filter eventlog event before $next event to determinate the last online state
            $var2=Get-EventLog -LogName system -Source EventLog |  where index -lt $next.Index | select -First 10

            #calculate elapsed time between start and stop event, 
            #The shutdown time is the last recorded online time on EventLog source ( just before $next event)
            $uptime=($var2[3].TimeGenerated-$wakeUpTime).TotalSeconds
            $TimeSpan=New-TimeSpan -Seconds $uptime

            #Log information to display
            "Sytem Wake up at :" + $wakeUpTime + " - Sleep at: " + $var2[3].TimeGenerated + " | Total uptime: " + $uptime+"("+$TimeSpan.Hours.ToString()+":"+$TimeSpan.Minutes.ToString()+":"+$TimeSpan.Seconds.ToString()+")"
            
            #Add currnet uptime to total
            $totalUpTime+=$uptime
            
            #save last sleep time for total time calculation
            $LastSleepTime=$var2[3].TimeGenerated

            
        }
        
        #store the last wakuptime
        $wakeUpTime=$next.TimeGenerated

        #save the first Wake up time for total time estimation
        if($FirstWakUpTime -eq 0)
        {
            $FirstWakUpTime=$next.TimeGenerated
        }
        
        #save last event log and type
        $LastEventType="started"
        $LastEvent=$next
    }
}



$TimeSpan=New-TimeSpan -Seconds $totalUpTime
"`nTotal Uptime: " + $totalUpTime+"("+$TimeSpan.Days.ToString()+" Day, "+$TimeSpan.Hours.ToString()+":"+$TimeSpan.Minutes.ToString()+":"+$TimeSpan.Seconds.ToString()+")"

$TotalTime=$LastSleepTime-$FirstWakUpTime
$TimeSpan=New-TimeSpan -Seconds $TotalTime.TotalSeconds
"`nTotal time: " + $TotalTime.TotalSeconds+"("+$TimeSpan.Days.ToString()+" Day, "+$TimeSpan.Hours.ToString()+":"+$TimeSpan.Minutes.ToString()+":"+$TimeSpan.Seconds.ToString()+")"

$UpTimePercent=$totalUpTime/$TotalTime.TotalSeconds*100
"`nUptime Percent: $UpTimePercent"
}


$signature = @"
	
	[DllImport("user32.dll")]  
	public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);  
	public static IntPtr FindWindow(string windowName){
		return FindWindow(null,windowName);
	}
	[DllImport("user32.dll")]
	public static extern bool SetWindowPos(IntPtr hWnd, 
	IntPtr hWndInsertAfter, int X,int Y, int cx, int cy, uint uFlags);
	[DllImport("user32.dll")]  
	public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); 
	static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
	static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
	const UInt32 SWP_NOSIZE = 0x0001;
	const UInt32 SWP_NOMOVE = 0x0002;
	const UInt32 TOPMOST_FLAGS = SWP_NOMOVE | SWP_NOSIZE;
	public static void MakeTopMost (IntPtr fHandle)
	{
		SetWindowPos(fHandle, HWND_TOPMOST, 0, 0, 0, 0, TOPMOST_FLAGS);
	}
	public static void MakeNormal (IntPtr fHandle)
	{
		SetWindowPos(fHandle, HWND_NOTOPMOST, 0, 0, 0, 0, TOPMOST_FLAGS);
	}
"@



$app = Add-Type -MemberDefinition $signature -Name Win32Window -Namespace ScriptFanatic.WinAPI -ReferencedAssemblies System.Windows.Forms -Using System.Windows.Forms -PassThru

function Set-AlwaysOnTop
{
<#
   
.DESCRIPTION
   This function will set or disable this console window to always on top.
       
.PARAMETER Disable
   This option will disable always on top settings for current console windows.
   

.EXAMPLE
    Set-AlwaysOnTop 
    Set-AlwaysOnTop -Disable

#>

	param(		
		#[Parameter(Position=0,ValueFromPipelineByPropertyName=$true)][Alias('MainWindowHandle')]$hWnd=0,
		[Parameter()][switch]$Disable
	)
	$hWnd=(Get-Process -Id $pid).MainWindowHandle
	if($hWnd -ne 0)
	{
		if($Disable)
		{
			Write-Verbose "Set process handle :$hWnd to NORMAL state"
			$null = $app::MakeNormal($hWnd)
			return
		}
		
		Write-Verbose "Set process handle :$hWnd to TOPMOST state"
		$null = $app::MakeTopMost($hWnd)
	}
	else
	{
		Write-Verbose "$hWnd is 0"
	}
}

$QuickEditCodeSnippet=@"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Runtime.InteropServices;


public static class DisableConsoleQuickEdit
{

    const uint ENABLE_QUICK_EDIT = 0x0040;

    // STD_INPUT_HANDLE (DWORD): -10 is the standard input device.
    const int STD_INPUT_HANDLE = -10;

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll")]
    static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll")]
    static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    public static bool SetQuickEdit(bool SetEnabled)
    {

        IntPtr consoleHandle = GetStdHandle(STD_INPUT_HANDLE);

        // get current console mode
        uint consoleMode;
        if (!GetConsoleMode(consoleHandle, out consoleMode))
        {
            // ERROR: Unable to get console mode.
            return false;
        }

        // Clear the quick edit bit in the mode flags
        if (SetEnabled)
        {
            consoleMode &= ~ENABLE_QUICK_EDIT;
        }
        else
        {
            consoleMode |= ENABLE_QUICK_EDIT;
        }

        // set the new mode
        if (!SetConsoleMode(consoleHandle, consoleMode))
        {
            // ERROR: Unable to set console mode
            return false;
        }

        return true;
    }
}




"@

$QuickEditMode=add-type -TypeDefinition $QuickEditCodeSnippet -Language CSharp


function Set-QuickEdit()
{
<#
   
.DESCRIPTION
   This function will set or disable the quick edit settings of this console window.
   Can be very useful to avoid accidently interrupt long running Powershell scripts by mouse clicking.
       
.PARAMETER Disable
   This option will quick edit option on this console window.
   

.EXAMPLE
    Set-AlwaysOnTop 
    Set-AlwaysOnTop -DisableQuickEdit

#>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$false, HelpMessage="This switch will disable Console QuickEdit option")]
        [switch]$DisableQuickEdit=$false
    )
    
    
        if([DisableConsoleQuickEdit]::SetQuickEdit($DisableQuickEdit))
        {
            Write-Output "QuickEdit settings has been updated."
        }
        else
        {
            Write-Output "Something went wrong."
        }
}

Function Watch()
{
     <#
   
.DESCRIPTION
   This function a simplified clone of linux watch command.
   It will execute the given command periodicly
   
       
.PARAMETER Delay
   You can specify the delay time between two command execution.
.PARAMETER KeepLog
   This switch will keep the history of the continues command execution.
.PARAMETER CommandString
   Specify the command that you want to monitor. If command contain space, use ""


.EXAMPLE
   watch -Delay 1 -CommandString "Get-publicip" -KeepLog
   watch -CommandString "show-ipconfig 'Wifi Adapter'"

   
#>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$false, HelpMessage="Set sleep time for refresh")][int]$Delay=1, 
    [Parameter(Mandatory=$false, HelpMessage="This switch will keep the console history")][switch]$KeepLog=$false, 
    [Parameter(Mandatory=$true, HelpMessage="Define command to monitor")][string]$CommandString

    )
    $cmd = [scriptblock]::Create($CommandString);
    while($true)
    {
        $time=get-date
        $time="$time | $CommandString `n----------------------------------------------------------------------------------`n`n" 
        if(-not $KeepLog)
        {
            Clear-Host
            $time
        }
        
        
        $cmd.Invoke();
        
        sleep $Delay
        
    }
}
