/*关于此文件的注释*/
#include <stdio.h>
#include <stdlib.h>

__global__  void test(){
    double a = 1.01;
    float b = 1.01;
    for (int i = 0; i < 10; i++)
    {
        a = a * a;
        b = b * b;
    }
    printf("down thread %d \n",threadIdx.x);
    printf("%f \n%f \n",a,b);
}

void main() { 
    uint32_t a = 56;
    uint32_t temp = 0;
    int list[32];
    for (int i = 0; i < 32; i++)
    {
      list[i] = 0;
    }

    for (int i = 0; i < 4*sizeof(uint32_t); i++)
    {   
        if((a>>i)&0xfffffffe){
          printf("v + 1\n");
          list[i] = 1;
        } 
    }   
    for (int i = 0; i < 32; i++)
    {
      printf("%d ", list[i]);
    }
    
}