#include "common.h"
char* ConvertToString(const char* pFileName)
{
	size_t		uiSize = 0;
	size_t		uiFileSize = 0;
	char* pStr = NULL;
	std::fstream fFile(pFileName, (std::fstream::in | std::fstream::binary));
	if (fFile.is_open())
	{
		fFile.seekg(0, std::fstream::end);
		uiSize = uiFileSize = (size_t)fFile.tellg();  // 获得文件大小
		fFile.seekg(0, std::fstream::beg);
		pStr = (char*)malloc(sizeof(char) * uiSize + 1);
		if (NULL == pStr)
		{
			fFile.close();
			exit(-1);
		}
		fFile.read(pStr, uiFileSize);				// 读取uiFileSize字节
		fFile.close();
		pStr[uiSize] = '\0';

		return pStr;
	}
	cout << "Error: Failed to open cl file\n:" << pFileName << endl;
	exit(-1);
}