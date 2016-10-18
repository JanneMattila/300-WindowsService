#include "stdafx.h"

int main()
{
    TCHAR value[256] = TEXT("");
    DWORD size = sizeof(value);
    
    // Headers
    std::cout << "Content-type: text/html" << std::endl << std::endl;

    // Content
    std::cout << "<html>" << std::endl;
    std::cout << "<head><meta http-equiv=\"refresh\" content=\"1\"></head>" << std::endl;
    std::cout << "<body>" << std::endl;
    std::cout << "This content is coming from C++ application!<br />" << std::endl;
    LSTATUS status = RegGetValue(HKEY_LOCAL_MACHINE, 
        TEXT("SOFTWARE\\LOBService"), 
        TEXT("ServiceText"), RRF_RT_REG_SZ, nullptr, &value, &size);
    if (ERROR_SUCCESS == status)
    {
        std::cout << "This content is coming from Back-end Windows Service:<br />" << std::endl;
        std::wcout << value << std::endl;
    }
    else
    {
        std::cout << "But we don't yet have content coming from the Windows Service." << std::endl;
    }

    std::cout << "</body></html>" << std::endl;
    return 0;
}

