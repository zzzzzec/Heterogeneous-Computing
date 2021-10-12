#include<stdio.h>

int main(){
    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(deviceProp,0);
    printf("name %s \n",deviceProp.name);
    printf("SM = %d\n",deviceProp.multiProcessorCount);
    printf("shared memory = %d\n",deviceProp.sharedMemPerBlock);
    
}