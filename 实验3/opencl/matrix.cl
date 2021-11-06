#include "matrix.h"

#define index(raw,column) ((raw * MATRIX_SIZE) + column)
#define addr(base,raw,column) ( base + (raw*MATRIX_SIZE) + column )
#define  DEBUG

__kernel void display(const TYPE* base) {
	for (int i = 0; i < MATRIX_SIZE; i++) {
		for (int j = 0; j < MATRIX_SIZE; j++) {
			printf("%f	", base[index(i, j)]);
		}
		printf("\n");
	}
	printf("\n");
}
__kernel void memcpy(void* dest, const void* src, const unsigned int size) {
	unsigned int i= 0;
	for (; i < size; i++) {
		((char*)dest)[i] = ((char*)src)[i];
	}
}
//����ÿһ�� �� �� ������һ��Ԫ��
__kernel void cal(const TYPE* left, const TYPE* right, int raw, int column, TYPE* result) {
	TYPE temp = 0;
	//printf("cal raw = %d , clo = %d \n", raw, column);
	for (int i = 0; i < MATRIX_SIZE ; i++) {
		//printf("left = %f , right = %f \n", left[index(raw, i)], right[index(i, column)]);
		temp += left[index(raw, i)] * right[index(i,column)];
	}
	*result = temp;
}
//���룺A �� ��ʱ���� temp ����� result �ڼ����У�A ʼ���� ���
__kernel void matrix(__global const TYPE* A , __global TYPE* temp, __global TYPE* result ,const int times , const int raw_n) {
	const int start = get_global_id(0) * raw_n; //ÿһ���߳���ʼ������
	const int end = start + raw_n;
	int raw = start;
	int column = 0;
#ifdef DEBUG
	//printf("thread ID = %d , start = %d end = %d , raw_n = %d , times = %d \n", get_global_id(0) ,start, end , raw_n , times);
#endif

	for (int round = 0 ;round < times ; round++) {
		raw = start;
		column = 0;
		for (; raw < end;  raw++) {
			for (; column < MATRIX_SIZE; column++) {  
				cal(A, temp, raw, column, addr(result,raw,column));
#ifdef DEBUG
				//printf("result[%d,%d] = %f \n", raw, column, *addr(result, raw, column));
#endif 
			}
			column = 0;
		}
		//ÿһ�ּ������,ͬ���ڴ� result -> temp
		memcpy(addr(temp,start,0) , addr(result,start,0) , SIZE_PER_RAW*raw_n );
		barrier(CLK_GLOBAL_MEM_FENCE);
	}
}