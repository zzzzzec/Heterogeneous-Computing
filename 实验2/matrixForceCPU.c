/*关于此文件的注释*/
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <pthread.h>
#include <assert.h>


#define N 512
#define TIMES 10
#define MATRIX_SIZE N *N *(sizeof(double))
#define THREAD_NUMBER 8
#define LINE_PER_THREAD (N / THREAD_NUMBER)

#define MUTI_THREAD

void printMatrix(double *A);
void muti_self(double *base);
void muti_fast_template(int times, int section, double *base, double **section_list);
pthread_cond_t cond;
pthread_mutex_t mutex;
pthread_barrier_t barrier_in;
pthread_barrier_t barrier_out;
pthread_barrier_t barrier_memory_syn;

double *A;
double *result;

double *thread_base;

typedef struct
{
    int available;
    double *result;
} list;

typedef struct
{
    int start;
    int len;
} Arg;

/*
    给出x，y返回地址
*/
double *getAddr(double *base, int x, int y)
{
    return (base + (x * N) + y);
}

double getValue(double *base, int x, int y)
{
    return *(base + (x * N) + y);
}

void init(double *base, double value)
{
    double *index = base;
    for (int i = 0; i < N * N; i++)
    {
        *(index) = value;
        index += 1;
    }
}
/*
    矩阵乘法：左边的x行乘以右边的y
    retrun 单个元素结果
*/
double muti_matrix_template(double *left, double *right, int x, int y)
{
    double result = 0.0;
    for (int i = 0; i < N; i++)
    {
       //assert(getValue(left, x, i) < 600);
        result += (getValue(left, x, i) * getValue(right, i, y));
    }
    return result;
}

void muti_matrix(double *left, double *right, double *result)
{
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; j++)
        {
            *(getAddr(result, i, j)) = muti_matrix_template(left, right, i, j);
        }
    }
}

void muti(double *base, int times, double *result)
{
    memcpy(result, base, MATRIX_SIZE);
    if (times == 1)
    {
        return;
    }
    double *temp = (double *)malloc(MATRIX_SIZE);
    for (int round = 0; round < times - 1; round++)
    {
        memcpy(temp, result, MATRIX_SIZE);
        muti_matrix(temp, base, result);
        printf("完成第 %d 次运算 result = %f\n", round + 1,*result);
    }
}

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

void print_list(list *result_list)
{
    for (int i = 0; i < 32; i++)
    {
        printf("list[%d]  a = %d , result = %p  ", i, result_list[i].available,
               result_list[i].result);
        if (result_list[i].result != NULL)
        {
            printf("first elm = %f \n", *(result_list[i].result));
        }
        else
            printf("\n");
    }
}

void muti_fast(double *base, int times, double *result)
{
    if (times == 1)
    {
        memcpy(result, base, MATRIX_SIZE);
        return;
    }

    list *result_list = (list *)malloc(sizeof(list) * (32));
    for (int i = 0; i < 32; i++)
    {
        result_list[i].available = 0;
        result_list[i].result = NULL;
    }
    set_list(result_list, times);
    int max_exp = floor(log2(times));

    double *temp = (double *)malloc(MATRIX_SIZE);
    memcpy(temp, base, MATRIX_SIZE);

    for (int i = 1; i < max_exp + 1; i++)
    {
#ifdef MUTI_THREAD
        thread_base = temp;
        //printf("================%d====================\n",i);
        pthread_barrier_wait(&barrier_in);
        //sleep(3);
        pthread_barrier_wait(&barrier_out);

        //printf("first_elm = %f \n", *thread_base);
        //printf("======================================\n\n\n");
#else
        muti_self(temp);
#endif
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
                memcpy(result, result_list[i].result, MATRIX_SIZE);
                flag = 0;
            }
            else
            {
                muti_matrix(fin_temp, result_list[i].result, result);
            }
            memcpy(fin_temp, result, MATRIX_SIZE);
        }
    }
}

void muti_self(double *base)
{
    double *temp = (double *)malloc(MATRIX_SIZE);
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; j++)
        {
            (*(getAddr(temp, i, j))) = muti_matrix_template(base, base, i, j);
        }
    }
    memcpy(base, temp, MATRIX_SIZE);
    free(temp);
}

void* muti_self_mutithread(void *args)
{
    int start = ((Arg *)(args))->start;
    int len = ((Arg *)(args))->len;
    //printf("CREATE THERAD %d SUCCESS [%d,%d) \n",pthread_self(), start, start + len);

    while (1)
    {
        pthread_barrier_wait(&barrier_in);

        //printf("thread %d CROSS barrier \n", pthread_self());
        double *temp = (double *)malloc(MATRIX_SIZE / THREAD_NUMBER);
        for (int i = start; i < start + len; i++)
        {
            for (int j = 0; j < N; j++)
            {
                (*(getAddr(temp, i - start, j))) = muti_matrix_template(thread_base, thread_base, i, j);
            }
        }
        //printf("memcpy %p -> %p len = %d start = %d\n", temp, thread_base + (start * N), MATRIX_SIZE / THREAD_NUMBER,start);
        //终于找到这个bug了，内存不同步，memcpy必须要所有的线程都完成计算之后才可以进行，不然
        //慢的线程取到的数据是快的线程写道 thread_base 的结果，导致内存不同步
        //注意：在对指针进行加减运算的时候，编译器会自动根据指针的类型选择步长，不需要再 *(sizeof(type))
        pthread_barrier_wait(&barrier_memory_syn);
        
        memcpy(thread_base + ((start * N)), temp, MATRIX_SIZE / THREAD_NUMBER);
        free(temp);
        
        pthread_barrier_wait(&barrier_out);
    }
}

void printMatrix(double *A)
{
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; j++)
        {
            printf("%f ", getValue(A, i, j));
        }
        printf("\n");
    }
}

void create_tread(pthread_t *handle, int number)
{
    for (int i = 0; i < number; i++)
    {
        Arg *args = (Arg *)malloc(sizeof(Arg));
        args->start = i * LINE_PER_THREAD;
        args->len = LINE_PER_THREAD;
        if (pthread_create(&(handle[i]), NULL, muti_self_mutithread, (void *)args) != 0)
        {
            printf("create_thread: ERROR \n");
            exit(-1);
        }
    }
}

void main()
{
    pthread_mutex_init(&mutex, NULL);
    pthread_cond_init(&cond, NULL);
    pthread_barrier_init(&barrier_in, NULL , THREAD_NUMBER + 1);
    pthread_barrier_init(&barrier_out, NULL , THREAD_NUMBER + 1);
    pthread_barrier_init(&barrier_memory_syn, NULL, THREAD_NUMBER);
    A = (double *)malloc(MATRIX_SIZE);
    result = (double *)malloc(MATRIX_SIZE);
    init(A, 1.01);
    init(result, 0.0);
    int times;
    int prog;
    scanf("%d", &times);
    printf("confirm times = %d\n", times);
    printf("use pro :");
    scanf("%d", &prog);
    double start = clock();
    if (prog){

#ifdef MUTI_THREAD
        pthread_t *handle = (pthread_t *)malloc(sizeof(pthread_t) * THREAD_NUMBER);
        create_tread(handle , THREAD_NUMBER);
#endif
        printf("fast prog\n");
        muti_fast(A, times, result);
    }
    else
    {
        printf("normal prog\n");
        muti(A, times, result);
    }
    double end = clock();
    printf("USING TIME = %f \n", end - start);
    printf("first elm = %f \n", *result);
    //printMatrix(result);
    return;
}
