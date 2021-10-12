#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <unistd.h>
pthread_barrier_t barrier1;
pthread_barrier_t barrier2;

void* initor(void* args) {
	printf("---------------thread init work(%d)--------------\n", time(NULL));
    while (1)
    {
        sleep(2);
	    pthread_barrier_wait(&barrier1);
        printf("thread : GO GO GO!!!\n");
        pthread_barrier_wait(&barrier2);
        printf("FINISH \n");
    }
    

	printf("--------------thread start work(%d)--------------\n", time(NULL));
	sleep(10);
	printf("--------------thread stop work(%d)--------------\n", time(NULL));
	return NULL;
}

int main(int argc, char* argv[]) {
  	//初始化栅栏，该栅栏等待两个线程到达时放行
	pthread_barrier_init(&barrier1, NULL, 2);
    pthread_barrier_init(&barrier2, NULL, 2);
	printf("**************main thread barrier init done****************\n");
	pthread_t pid;
	pthread_create(&pid, NULL, &initor, NULL);
	printf("**************main waiting(%d)********************\n", time(NULL));
	//主线程到达，被阻塞，当初始化线程到达栅栏时才放行。
    while (1)
    {
  	    pthread_barrier_wait(&barrier1);
        printf("main: GO GO GO！！！\n");
        sleep(10);
        pthread_barrier_wait(&barrier2);
        printf("main ： FINFISH \n");

    }
	printf("***************main start to work(%d)****************\n", time(NULL));
	sleep(30);
	pthread_join(pid, NULL);
	printf("***************thread complete(%d)***************\n", time(NULL));
	return 0;
}