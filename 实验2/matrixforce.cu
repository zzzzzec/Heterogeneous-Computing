/*关于此文件的注释*/
#include <stdio.h>
#include <stdlib.h>
//最小调度单位 warp 一个 warp有32个线程
// warp之间都是同步的，__syncthreads（）可以保证一个block内的warp是同步的
// 有点像 barrier ，所有的线程都执行到 __syncthreads 之后才会继续向前运行
//"D:\Visual Studio\VC\Tools\MSVC\14.29.30133\bin\Hostx86\x64"
#define N 512
#define TIMES 32
#define MATRIX_SIZE N*N*(sizeof(TYPE))
#define WARPNUMBER N/32

#define TYPE double

TYPE* h_A;//矩阵指针
TYPE* h_result;
TYPE* temp;  

__device__ TYPE* getAddr(TYPE* base , int x , int y){
    return (base + (x * N) + y); 
}

__device__ TYPE getValue(TYPE* base , int x , int y){
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

__device__ TYPE syncCaculate_template(TYPE* left , TYPE* right , int raw , int column){
    TYPE result = 0.0;
    for (int i = 0; i < N ; i++)
    {
        result += (getValue(left,raw,i) * getValue(right,i,column));   
    }
    return result;
}

__device__ TYPE syncCaculate_template_shared(TYPE* left , TYPE* shared_elm , int raw , int column){
    TYPE result = 0.0;
    for (int i = 0; i < N ; i++)
    {
        result += (getValue(left,raw,i) * *shared_elm );   
    }
    return result;
}

__global__ void syncCaculate(TYPE* d_A , TYPE* d_result , TYPE* d_temp , int rawPerThread , int times){
    //再考虑一下memcpy的位置，不能一个线程就把所有的memroy都cpoy完了
    //每个线程只CPOY自己的那一步分就好
    int tid = threadIdx.x; //+ (blockIdx.x*blockDim.x);
    //__shared__  TYPE d_A[N*N];
    __shared__ TYPE shared_elm ;
    if(tid == 1){
        shared_elm = 1.01;
    }
    //printf("%d %d %d %d \n",tid,threadIdx.x,blockDim.x,blockIdx.x);
    if(tid >= 512){
        return;
    }
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
                *(getAddr(d_result,raw,column)) = syncCaculate_template_shared(d_temp , &shared_elm , raw , column);
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

int main(){
    h_A = (TYPE*)malloc(MATRIX_SIZE);
    h_result = (TYPE*)malloc(MATRIX_SIZE);
    init(h_A,1.01);
    init(h_result,0.0);

    TYPE* d_A;
    TYPE* d_result;
    TYPE* d_temp;
    cudaMalloc( ((void**)(&d_A)) , MATRIX_SIZE);
    cudaMalloc( ((void**)(&d_result)) , MATRIX_SIZE);
    cudaMalloc( ((void**)(&d_temp)) , MATRIX_SIZE);

    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp,0);
    printf("name:%s\n",deviceProp.name);
    printf("SM = %d\n",deviceProp.multiProcessorCount);
    printf("share memory = %zd\n",deviceProp.sharedMemPerBlock);
    cudaMemcpy(d_A , h_A , MATRIX_SIZE ,cudaMemcpyHostToDevice);

    int threadNumber = 512;
    int blockNumber = 1;
    dim3 block(threadNumber,1,1);
    dim3 grid(blockNumber,1,1);
    //int rawPerThread = N/(threadNumber*blockNumber);
    int rawPerThread = 1;
    printf("BLOCK =  (%d,%d,%d) GRID = (%d,%d,%d) \n",threadNumber,1,1,blockNumber,1,1);
    printf("rawPerThread = %d \n",rawPerThread);
    syncCaculate<<<grid,block>>>(d_A , d_result , d_temp , rawPerThread , TIMES);

    cudaMemcpy(h_result , d_result , MATRIX_SIZE , cudaMemcpyDeviceToHost);
    printf("first_elm = %f\n",*h_result);

    return 0;
}