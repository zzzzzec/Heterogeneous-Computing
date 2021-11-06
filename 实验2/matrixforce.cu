/*关于此文件的注释*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include "device_functions.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

//最小调度单位 warp 一个 warp有32个线程
// warp之间都是同步的，__syncthreads（）可以保证一个block内的warp是同步的
// 有点像 barrier ，所有的线程都执行到 __syncthreads 之后才会继续向前运行
//"D:\Visual Studio\VC\Tools\MSVC\14.29.30133\bin\Hostx86\x64"
#define N 512
#define TIMES 10
#define MATRIX_SIZE N*N*(sizeof(TYPE))
#define WARPNUMBER N/32
#define FAST

#define TYPE double

TYPE* h_A;//矩阵指针
TYPE* h_result;
//TYPE* temp;  

typedef struct
{
    int available;
    double *result;
} list;

void set_list(list *result_list, int times)
{
    for (int i = 0; i < 32; i++)
    {
        if ((times >> i) & 0x00000001)
        {
            result_list[i].available = 1;
        }
    }
}

void mem_check(TYPE* base, float min, float max) {
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; j++)
        {
            assert(*(base + i * N + j) < max && *(base + i * N + j) > min);
        }
    }
}
double* getAddr(double* base, int x, int y)
{
    return (base + (x * N) + y);
}

double getValue(double* base, int x, int y)
{
    return *(base + (x * N) + y);
}

/*
    矩阵乘法：左边的x行乘以右边的y
    retrun 单个元素结果
*/
double muti_matrix_template(double* left, double* right, int x, int y)
{
    double result = 0.0;
    for (int i = 0; i < N; i++)
    {
        //assert(getValue(left, x, i) < 600);
        result += (getValue(left, x, i) * getValue(right, i, y));
    }
    return result;
}

void muti_matrix(double* left, double* right, double* result)
{
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; j++)
        {
            *(getAddr(result, i, j)) = muti_matrix_template(left, right, i, j);
        }
    }
}

__device__ TYPE* d_getAddr(TYPE* base , int x , int y){
    return (base + (x * N) + y); 
}

__device__ TYPE d_getValue(TYPE* base , int x , int y){
    return *(base + (x * N) + y);
}

void init(TYPE* base , TYPE value){
    TYPE* index = base;
    for (int i = 0; i < N*N ; i++)
    {
        *(index) = value;
        index += 1;
    }
}

__device__ TYPE d_syncCaculate_template(TYPE* left , TYPE* right , int raw , int column){
    TYPE result = 0.0;
    for (int i = 0; i < N ; i++)
    {
        result += (d_getValue(left,raw,i) * d_getValue(right,i,column));   
    }
    return result;
}

__device__ TYPE d_syncCaculate_template_shared(TYPE* left , TYPE* shared_elm , int raw , int column){
    TYPE result = 0.0;
    for (int i = 0; i < N ; i++)
    {
        result += (d_getValue(left,raw,i) * *shared_elm );   
    }
    return result;
}

__global__ void syncCaculate(TYPE* d_A , TYPE* d_result , TYPE* d_temp , int rawPerThread , int times){
    //再考虑一下memcpy的位置，不能一个线程就把所有的memroy都cpoy完了
    //每个线程只CPOY自己的那一步分就好
    int tid = threadIdx.x; //+ (blockIdx.x*blockDim.x);
    //printf("%d %d %d %d \n",tid,threadIdx.x,blockDim.x,blockIdx.x);
    int start = tid * rawPerThread;
    int end = tid * rawPerThread + rawPerThread;
    int startMemOffset = (start * N);
    int copySize = (rawPerThread * N)*(sizeof(TYPE));

    //printf("thread %d : [%d,%d] startMemOffset = %d copySize = %d\n",tid,start,end-1,startMemOffset,copySize);
    
    memcpy(d_result + startMemOffset , d_A + startMemOffset, copySize);
    if(times == 1){
        return ;
    }
    memcpy(d_temp + startMemOffset , d_A + startMemOffset, copySize);
    for (int i = 0; i < times - 1 ; i++)
    {
        for (int raw = start ; raw < end ; raw ++)
        {
            for (int column = 0; column < N; column++)
            {
                *(d_getAddr(d_result, raw, column)) = d_syncCaculate_template(d_temp, d_A, raw, column);
            }
        }
        //覆盖问题，每个线程只复制自己那一部分内存
        memcpy(d_temp + startMemOffset , d_result + startMemOffset, copySize);
        //if(threadIdx.x == 0){
           //printf("ROUND=%d = %f\n",i,d_result[0]);
        //}
        __syncthreads();    
    }    

    //printf("thread BLOCK=(%d,%d,%d) GRID=(%d,%d,%d) : down \n",threadIdx.x,threadIdx.y,threadIdx.z,blockIdx.x,blockIdx.y,blockIdx.z);
    //printf("NOT BE THERE \n");
}

__global__ void synccalculate_fast(TYPE* base, int rawPerThread){
    int tid = threadIdx.x; //+ (blockIdx.x*blockDim.x);
    //printf("%d %d %d %d \n",tid,threadIdx.x,blockDim.x,blockIdx.x);
    int start = tid * rawPerThread;
    int end = tid * rawPerThread + rawPerThread;
    int startMemOffset = (start * N);
    int copySize = (rawPerThread * N)*(sizeof(TYPE));
    TYPE *temp = (TYPE *)malloc(copySize);

    for (int raw = start ; raw < end ; raw ++)
    {
        for (int column = 0; column < N; column++)
        {
                *(d_getAddr(temp, raw - start, column)) = d_syncCaculate_template(base, base, raw, column);
        }
    }
    __syncthreads();
    memcpy(base + startMemOffset, temp, copySize);
    __syncthreads();
}

int main(){
    h_A = (TYPE*)malloc(MATRIX_SIZE);
    h_result = (TYPE*)malloc(MATRIX_SIZE);
    init(h_A,1.01);
    init(h_result,0.0);

    int times = TIMES;

    int threadNumber = 512;
    int blockNumber = 1;
    dim3 block(threadNumber,1,1);
    dim3 grid(blockNumber,1,1);
    //int rawPerThread = N/(threadNumber*blockNumber);
    int rawPerThread = 1;
    printf("BLOCK =  (%d,%d,%d) GRID = (%d,%d,%d) \n",threadNumber,1,1,blockNumber,1,1);
    printf("rawPerThread = %d \n",rawPerThread);

    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp,0);
    printf("name:%s\n",deviceProp.name);
    printf("SM = %d\n",deviceProp.multiProcessorCount);
    printf("share memory = %zd\n",deviceProp.sharedMemPerBlock);
  
#ifndef FAST
    TYPE* d_A;
    TYPE* d_result;
    TYPE* d_temp;
    cudaMalloc( ((void**)(&d_A)) , MATRIX_SIZE);
    cudaMalloc( ((void**)(&d_result)) , MATRIX_SIZE);
    cudaMalloc( ((void**)(&d_temp)) , MATRIX_SIZE);

    cudaMemcpy(d_A , h_A , MATRIX_SIZE ,cudaMemcpyHostToDevice);

    syncCaculate<<<grid,block>>>(d_A , d_result , d_temp , rawPerThread , TIMES);

    cudaMemcpy(h_result , d_result , MATRIX_SIZE , cudaMemcpyDeviceToHost);
    printf("first_elm = %f\n",*h_result);

#else
    TYPE* d_base;
    cudaMalloc(((void**)(&d_base)), MATRIX_SIZE);
    TYPE* temp = (TYPE*)malloc(MATRIX_SIZE);
    memcpy(temp, h_A, MATRIX_SIZE);
    
    list *result_list = (list *)malloc(sizeof(list) * (32));
    for (int i = 0; i < 32; i++)
    {
        result_list[i].available = 0;
        result_list[i].result = NULL;
    }

    set_list(result_list, times);

    int max_exp = floor(log2(times));

    for (int i = 1; i < max_exp + 1; i++)
    {
        cudaMemcpy(d_base, temp, MATRIX_SIZE, cudaMemcpyHostToDevice);
        synccalculate_fast << <grid, block >> > (d_base, rawPerThread);
        cudaMemcpy(temp, d_base, MATRIX_SIZE, cudaMemcpyDeviceToHost);
        cudaDeviceSynchronize();

        if (result_list[i].available)
        {
            printf("add %d \n", i);
            double *add_to_result_list = (double *)malloc(MATRIX_SIZE);
            memcpy(add_to_result_list, temp, MATRIX_SIZE);
            result_list[i].result = add_to_result_list;
        }
    }

    //print_list(result_list);
    int flag = 1;
    double *fin_temp = (double *)malloc(MATRIX_SIZE);
    for (int i = 0; i < 32; i++)
    {
        if (result_list[i].available != 0)
        {
            if (flag)
            {
                memcpy(h_result, result_list[i].result, MATRIX_SIZE);
                memcpy(fin_temp, result_list[i].result, MATRIX_SIZE);
                flag = 0;
            }
            else
            {
                muti_matrix(fin_temp, result_list[i].result, h_result);
            }
            memcpy(fin_temp, h_result, MATRIX_SIZE);
        }
    }


#endif
    printf("first_elm = %f \n", h_result[0]);
    return 0;
}