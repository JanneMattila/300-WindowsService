#include "stdafx.h"
//
// Windows Service example is based on MSDN content:
// https://msdn.microsoft.com/en-us/library/windows/desktop/ms687416(v=vs.85).aspx
// https://msdn.microsoft.com/en-us/library/windows/desktop/ms687414(v=vs.85).aspx
// https://msdn.microsoft.com/en-us/library/windows/desktop/ms687413(v=vs.85).aspx
//

SERVICE_STATUS g_serviceStatus{};
SERVICE_STATUS_HANDLE g_statusHandle = nullptr;
HANDLE g_serviceStopEvent = INVALID_HANDLE_VALUE;
std::chrono::time_point<std::chrono::system_clock> g_start;

VOID ReportStatus(DWORD dwCurrentState,
	DWORD dwWin32ExitCode = NO_ERROR,
	DWORD dwWaitHint = 3000)
{
	static DWORD dwCheckPoint = 1;

	g_serviceStatus.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
	g_serviceStatus.dwCurrentState = dwCurrentState;
	g_serviceStatus.dwWin32ExitCode = dwWin32ExitCode;
	g_serviceStatus.dwWaitHint = dwWaitHint;

	if (dwCurrentState == SERVICE_START_PENDING)
		g_serviceStatus.dwControlsAccepted = 0;
	else g_serviceStatus.dwControlsAccepted = SERVICE_ACCEPT_STOP;

	if ((dwCurrentState == SERVICE_RUNNING) ||
		(dwCurrentState == SERVICE_STOPPED))
		g_serviceStatus.dwCheckPoint = 0;
	else g_serviceStatus.dwCheckPoint = dwCheckPoint++;

	// Report the status of the service to the SCM.
	SetServiceStatus(g_statusHandle, &g_serviceStatus);
}

DWORD WINAPI ServiceCtrlHandler(DWORD controlCode, DWORD, LPVOID, LPVOID)
{
	switch (controlCode)
	{
		case SERVICE_CONTROL_STOP:
			if (g_serviceStatus.dwCurrentState != SERVICE_RUNNING)
			{
				break;
			}

			ReportStatus(SERVICE_STOP_PENDING);
			SetEvent(g_serviceStopEvent);
			break;
		default:
			break;
	}

	return NO_ERROR;
}

DWORD WINAPI ServiceWorkerThread(LPVOID lpParam)
{
	TCHAR machineName[256] = TEXT("");
	DWORD dwSize = sizeof(machineName);
	GetComputerName(machineName, &dwSize);

	while (WaitForSingleObject(g_serviceStopEvent, 0) != WAIT_OBJECT_0)
	{
		auto runningTime = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now() - g_start);
		std::wostringstream logMessage;
		logMessage <<
			machineName << " machine has been running this service for " <<
			runningTime.count() << " seconds.";

		std::wstring text = logMessage.str();
		HKEY hkResult{};
		DWORD dwDisposition{};
		LSTATUS status = RegCreateKeyEx(
			HKEY_LOCAL_MACHINE, TEXT("SOFTWARE\\LOBService"), 0, nullptr, 0, 
			KEY_ALL_ACCESS, nullptr, &hkResult, &dwDisposition);
		if (ERROR_SUCCESS == status)
		{
			DWORD length = static_cast<DWORD>((text.length() + 1) * sizeof(TCHAR));
			status = RegSetKeyValue(hkResult, 0, TEXT("ServiceText"), REG_SZ, text.c_str(), length);
			RegCloseKey(hkResult);
		}

		Sleep(1000);
	}

	return ERROR_SUCCESS;
}

VOID WINAPI ServiceMain(DWORD argc, LPTSTR *argv)
{
	g_statusHandle = RegisterServiceCtrlHandlerEx(TEXT("LOB Service"), ServiceCtrlHandler, nullptr);
	ReportStatus(SERVICE_START_PENDING);

	g_serviceStopEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);
	ReportStatus(SERVICE_RUNNING);

	WaitForSingleObject(CreateThread(nullptr, 0, ServiceWorkerThread, nullptr, 0, nullptr), INFINITE);
	CloseHandle(g_serviceStopEvent);

	ReportStatus(SERVICE_STOPPED);
}

int main()
{
	g_start = std::chrono::system_clock::now();
	SERVICE_TABLE_ENTRY services[] =
	{
		{ TEXT(""), ServiceMain },
		{ nullptr, nullptr }
	};

	if (StartServiceCtrlDispatcher(services) == FALSE)
	{
		return GetLastError();
	}
	return 0;
}
