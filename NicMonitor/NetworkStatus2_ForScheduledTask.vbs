Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\FDT\NetworkStatus2.ps1""", 0
