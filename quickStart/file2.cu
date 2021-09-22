#include <stdio.h>

__global__ void checkIndex(void){
    //printf("(%d,%d,%d) blockIndex(%d,%d,%d) blockDim(%d,%d,%d) GridDim(%d,%d,%d) \n",threadIdx.x , threadIdx.y , threadIdx.z , blockIdx.x , blockIdx.y , blockIdx.z,blockDim.x,blockDim.y,blockDim.z ,gridDim.x,gridDim.y,gridDim.z);
    int ix = threadIdx.x + (blockIdx.x * blockDim.x);
    int iy = threadIdx.y + (blockIdx.y * blockDim.y);
    int id = iy * (blockDim.x * gridDim.x) + ix;
    printf("thread id = %d \n",id);
}

int main(){
    int nElem = 6 ;
    dim3 block(4,2,1); 
    //dim3 grid((nElem + block.x - 1)/block.x);
    dim3 grid(2,3,1);
    printf("grid.x = %d grid.y = %d grid.z = %d \n",grid.x,grid.y,grid.z);
    printf("block.x = %d block.y = %d block.z = %d \n",block.x,block.y,block.z);
    //注意！！！ 是<<<grid,block>>>不要弄反了！！！
    checkIndex <<<grid,block>>> ();
    exit(-1);
}