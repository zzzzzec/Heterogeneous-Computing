/* 创建第一个线程。主进程结束，则撤销线程。 */
#include<Windows.h>
#include<stdio.h>
DWORD WINAPI ThreadFunc(LPVOID);

void main()
{
    HANDLE hThread;
    DWORD  threadId;
    hThread = CreateThread(NULL, 0, ThreadFunc, 0, 0, &threadId); // 创建线程
    printf("我是主线程， pid = %d\n", GetCurrentThreadId());  //输出主线程pid
    Sleep(2000);
}

DWORD WINAPI ThreadFunc(LPVOID p)
{
    printf("我是子线程， pid = %d\n", GetCurrentThreadId());   //输出子线程pid
    return 0;
}