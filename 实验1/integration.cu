#include <math.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>

// D:\Visual Studio\VC\Tools\MSVC\14.29.30133\bin\Hostx86\x64
#define TYPE double
#define N (1000*1000*100)
#define THREDA_N 5000 //分为SIZE个部分
#define PROCESSOR 8
#define GPU
#define MUTITHREAD
#define INFO
/*
    para:
        len: 每个线程需要循环的次数，第n个线程计算 [n*len , n*len + len ];
*/
#ifdef GPU
__global__ void d_integration(int len, TYPE *d_result) {
  int ix = threadIdx.x + (blockIdx.x * blockDim.x);
  int iy = threadIdx.y + (blockIdx.y * blockDim.y);
  int tId = iy * (blockDim.x * gridDim.x) + ix;
  //printf("GPU: thread ID = %d  calculate [%d,%d]\n", tId, tId * len,tId * len + len );
  for (int i = tId * len; i < tId * len + len; i++) {
    d_result[tId] += (1.0 / N) * (4.0 / (1.0 + (pow((i + 0.5) / N, 2.0))));
  }
}
__global__ void d_arctan(int len, TYPE *d_result){
  int ix = threadIdx.x + (blockIdx.x * blockDim.x);
  int iy = threadIdx.y + (blockIdx.y * blockDim.y);
  int tId = iy * (blockDim.x * gridDim.x) + ix;
  int sign = 0;
  tId%2==0?sign = -1:sign = 1;
  for (int i = tId*len ; i < tId*len + len ; i++)
  {
      d_result[tId] += sign*(1/(2(i+1) -1));
  }
}
#endif

TYPE h_integration() {
  TYPE result = 0;
  for (int i = 0; i < N; i++) {
    result += (1.0 / N) * (4.0 / (1.0 + (pow((i + 0.5) / N, 2.0))));
  }
  return result;
}

int main() {
#ifdef GPU
  #ifdef INFO
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);
    for(int i=0;i<deviceCount;i++)
    {
        cudaDeviceProp devProp;
        cudaGetDeviceProperties(&devProp, i);
        printf("USING GPU device %d : %s \n",i,devProp.name);
        printf("Total memory : %zd MB \n",devProp.totalGlobalMem/(1024*1024));
        printf("SM : %d \n",devProp.multiProcessorCount);
        printf("Shared Memory for each block %zd \n",devProp.sharedMemPerBlock);
        printf("MaxBlock(%d,%d,%d) MaxGrid(%d,%d,%d) \n",devProp.maxThreadsDim[0],devProp.maxThreadsDim[1],devProp.maxThreadsDim[2],devProp.maxGridSize[0],devProp.maxGridSize[1],devProp.maxGridSize[2]);
        printf("Major compute capability %d \n",devProp.major);

    }
  #endif
  int sizePerThread = N / THREDA_N;
  int sizeOfResult = sizeof(TYPE) * THREDA_N;
  TYPE *h_result = (TYPE *)malloc(sizeOfResult);
  memset(h_result, 0, sizeOfResult);

  TYPE *d_result;
  cudaError_t memallocError = cudaMalloc((TYPE **)&d_result, sizeOfResult);
  printf("cuda : malloc %s \n", cudaGetErrorString(memallocError));

  cudaError_t memcpyError = cudaMemcpy(d_result, h_result, sizeOfResult, cudaMemcpyHostToDevice);
  printf("cuda : malloc %s \n", cudaGetErrorString(memcpyError));

  dim3 block(500,2,1);
  dim3 grid(5,1,1);
  double dur;
  clock_t start,end;
  start = clock();
  d_integration<<<grid, block>>>(sizePerThread, d_result);

  cudaMemcpy(h_result, d_result, sizeOfResult, cudaMemcpyDeviceToHost);
  TYPE finResult = 0;
  for (int i = 0; i < THREDA_N; i++) {
   //printf("%f ", h_result[i]);
    finResult += h_result[i];
  }
  end = clock();
  dur = (double)(end - start);
  printf("CPU : Use Time:%f\n",(dur/CLOCKS_PER_SEC));
#else
  double dur;
  clock_t start,end;
  start = clock();
  TYPE finResult = h_integration();
  end = clock();
  dur = (double)(end - start);
  printf("CPU : Use Time:%f\n",(dur/CLOCKS_PER_SEC));
#endif

  printf("\n PI = %f \n ", finResult);
}