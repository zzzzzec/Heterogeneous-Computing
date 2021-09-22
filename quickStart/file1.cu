#include <stdio.h>
#include <Windows.h>
#include <time.h>

#define ARRAY_LEN (1000)
#define ARRAY_SIZE(type) (sizeof(type)*ARRAY_LEN)

__global__ void Summary(float* d_a , float* d_b , float* d_result){
    int i = threadIdx.x;
    {
       d_result[i] = d_a[i] + d_b[i];
    }
   
}

void display(float data[] , int len){
    for (int i = 0; i < len; i++)
    {
        printf("%f ",data[i]);
    }
    printf("\n");
}

void set_memory(float data[] , int len , float number){
    for (int i = 0; i < len; i++)
    {
        data[i] = number;
    }
    
}

int main(){
    float* h_a;
    float* h_b;
    float* h_recv_result;
    h_a = (float*)malloc(sizeof(float) * ARRAY_LEN);
    h_b = (float*)malloc(sizeof(float) * ARRAY_LEN);
    h_recv_result = (float*)malloc(sizeof(float) * ARRAY_LEN);
    //memset(h_a , 0 , ARRAY_SIZE);
    //memset(h_b , 0 , ARRAY_SIZE);
    set_memory(h_a , ARRAY_LEN , 10.0);
    set_memory(h_b , ARRAY_LEN , 20.0);

    float* d_a;
    float* d_b;
    float* d_c;
    cudaError_t d_memError;
    const char* d_memError_char;
    d_memError = cudaMalloc((float**)&d_a , ARRAY_SIZE(float) );
    d_memError_char = cudaGetErrorString(d_memError);
    printf("%s\n",d_memError_char);
    d_memError = cudaMalloc((float**)&d_b , ARRAY_SIZE(float) );
    d_memError_char = cudaGetErrorString(d_memError);
    printf("%s\n",d_memError_char);
    d_memError = cudaMalloc((float**)&d_c , ARRAY_SIZE(float) );
    d_memError_char = cudaGetErrorString(d_memError);
    printf("%s\n",d_memError_char);

    cudaMemcpy(d_a , h_a , ARRAY_SIZE(float) , cudaMemcpyHostToDevice);
    cudaMemcpy(d_b , h_b , ARRAY_SIZE(float) , cudaMemcpyHostToDevice);

    dim3 block(ARRAY_LEN);
    dim3 grid(ARRAY_LEN/block.x);
    double iStart = clock();
    Summary<<<grid,block>>>(d_a , d_b , d_c);   
    printf("execution configuration <<<%d,%d>>> \n",grid.x,block.x);
    cudaMemcpy(h_recv_result , d_c , ARRAY_SIZE(float) , cudaMemcpyDeviceToHost);
    printf("total time %f \n",iStart - clock());
    for (int i = 0; i < ARRAY_LEN ; i++)
    {
        printf("%f ",h_recv_result[i]);
    }
    

}