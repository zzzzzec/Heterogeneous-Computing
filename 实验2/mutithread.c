/*关于此文件的注释*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>

#define N 512
#define TIMES 32
#define MATRIX_SIZE N*N*(sizeof(double))
#define THREAD_NUMBER 8
#define LINE_PER_THREAD (N/THREAD_NUMBER)


void printMatrix(double* A);
void create_tread(pthread_t* handle , int number);
void* calculate(void* args);
pthread_barrier_t barrier1; //用于同步计算线程
pthread_barrier_t barrier2; //用于同步更新内存
double* A;//矩阵指针
double* result;
double* temp;  

typedef struct{
    int start;
    int len;
}Arg;

/*
    给出x，y返回地址
*/
double* getAddr(double* base , int x , int y){
    return (base + (x * N) + y); 
}

double getValue(double* base , int x , int y){
    return *(base + (x * N) + y);
}

void init(double* base , double value){
    double* index = base;
    for (int i = 0; i < N*N ; i++)
    {
        *(index) = value;
        index += 1;
    }
}
/*
    矩阵乘法：左边的x行乘以右边的y
    retrun 单个元素结果
*/
double muti_matrix_template(double* left , double* right , int x , int y){
    double result = 0.0;
    for (int i = 0; i < N; i++)
    {
        result += (getValue(left,x,i) * getValue(right,i,y));   
    }
    return result;
}

void muti(double* base , int times , double* result){
    memcpy(result , base , MATRIX_SIZE);
    if(times == 1){ return; }
    temp = (double*)malloc(MATRIX_SIZE);
    memcpy(temp , result , MATRIX_SIZE);

    pthread_t* handle = (pthread_t*)malloc(sizeof(pthread_t) * THREAD_NUMBER);
    create_tread(handle , THREAD_NUMBER);
    pthread_barrier_wait(&barrier2);
    for (int round = 0; round < times-1 ; round++)
    {
        pthread_barrier_wait(&barrier1);
        memcpy(temp , result , MATRIX_SIZE);
        pthread_barrier_wait(&barrier2);
        printf("ROUND=%d = %f\n",round,result[0]);
    }
}

void create_tread(pthread_t* handle , int number){
    for (int i = 0; i < number; i++)
    {
        Arg* args = (Arg*)malloc(sizeof(Arg));
        args -> start = i * LINE_PER_THREAD ;
        args -> len = LINE_PER_THREAD;
        if( pthread_create(&(handle[i]) , NULL , calculate , (void*)args ) != 0 ){
            printf("create_thread: ERROR \n");
            exit(-1);
        }
    }
}

void* calculate(void* args){
    int start = ((Arg*)(args)) -> start;
    int len = ((Arg*)(args)) -> len;
    printf("CREATE THERAD SUCCESS [%d,%d) \n",start,start+len);

    for (int i = 0; i < TIMES - 1; i++)
    {
        pthread_barrier_wait(&barrier2);
        //printf("内存更新完成\n");
        for (int i = start; i < start + len ; i++)
        {   
            for (int j = 0; j < N; j++)
            {
                (*(getAddr(result,i,j))) = muti_matrix_template(temp , A , i , j);
            }
        }
        //printf("计算完成\n");
        pthread_barrier_wait(&barrier1);
    }
    pthread_barrier_wait(&barrier2);
}

void printMatrix(double* A){
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N ; j++)
        {
            printf("%f ",getValue(A,i,j));
        }
        printf("\n");
    }
}

void main(){
    pthread_barrier_init(&barrier1 , NULL , THREAD_NUMBER + 1 );
    pthread_barrier_init(&barrier2 , NULL , THREAD_NUMBER + 1 );
    A = (double*)malloc(MATRIX_SIZE);
    result = (double*)malloc(MATRIX_SIZE);
    init(A,1.01);
    init(result,0.0);
    double start = clock();
    muti(A,TIMES,result);
    double end = clock();
    printf("USING TIME = %f \n",end-start);
    printf("first elm = %f \n",*result);
    //printMatrix(result);
    free(A);
    free(result);
    free(temp);
    return;
}
