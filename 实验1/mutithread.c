#include <math.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>
#include <pthread.h>

// D:\Visual Studio\VC\Tools\MSVC\14.29.30133\bin\Hostx86\x64
#define TYPE double
#define N (1000*1000*100)
#define THREDA_N 100  //分为SIZE个部分
#define PROCESSOR 8
#define LENPERTHERAD (N/PROCESSOR)
#define MUTITHREAD

typedef struct{
    int start;
    int len;
    TYPE* result;
}Args;

void* cacl(void* arg){
  int start = ((Args*)arg)->start;
  int len = ((Args*)arg)->len; 
  for (int i = start; i < start + len ; i++) {
    *(((Args*)arg)->result) += (1.0 / N) * (4.0 / (1.0 + (pow((i + 0.5) / N, 2.0))));
  }
}

TYPE h_integration_mutithread(){
    TYPE* result = (TYPE*)malloc(sizeof(TYPE)*PROCESSOR);
    memset(result,0,sizeof(TYPE)*PROCESSOR);
    pthread_t* thread_id;
    thread_id = (pthread_t*)malloc(sizeof(pthread_t) * PROCESSOR);
    for (int i = 0; i < PROCESSOR ; i++)
    {
      Args* newarg = (Args*)malloc(sizeof(Args));

      newarg->start = i * LENPERTHERAD ;
      newarg->len = LENPERTHERAD;
      newarg->result = &(result[i]);
      printf("thread %d : start = %d , len = %d , arg = %f \n ",i,newarg->start,newarg->len,*(newarg->result));

      if(pthread_create(&(thread_id[i]) , NULL , cacl , newarg) != 0){
        printf("thread create ERROR \n");
        exit(-1);
      }
    }
    printf("waiting join \n");
    for (int i = 0; i < PROCESSOR ; i++)
    {
      pthread_join(thread_id[i],NULL);
    }
    printf("finish\n");
    float finResult = 0;
    for (int i = 0; i < PROCESSOR ; i++)
    {
      finResult += result[i];
      printf("%f ",result[i]);
    }
    printf("\n");
    return finResult;
}



int main() {
  double dur;
  clock_t start,end;
  start = clock();
  #ifdef MUTITHREAD
    TYPE finResult = h_integration_mutithread();
  #else
    TYPE finResult = h_integration();
  #endif

  end = clock();
  dur = (double)(end - start);
  printf("CPU : Use Time:%f\n",(dur/CLOCKS_PER_SEC));

  printf("\n PI = %f \n ", finResult);
}