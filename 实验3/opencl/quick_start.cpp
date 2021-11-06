#include "common.h"
#include "time.h"
#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

#pragma warning( disable : 4996 )
TYPE A[MATRIX_SIZE * MATRIX_SIZE];
TYPE temp[MATRIX_SIZE * MATRIX_SIZE];
TYPE result[MATRIX_SIZE * MATRIX_SIZE];

#define CHECK_MATRIX(base,x) for(int i = 0 ; i < (MATRIX_SIZE*MATRIX_SIZE); i++ ){\
                                    if (base[i] < x){\
                                        printf("base[%d] = %f ",i,base[i]);\
                                        return -1;\
                                    }\
                             }\

int main(void) {
    // Create the two input vectors
    for (int i = 0; i < (MATRIX_SIZE*MATRIX_SIZE); i++)
    {
        A[i] = 1.01;
        temp[i] = A[i];
        result[i] = 0;
    }

    // Get platform and device information
    cl_uint ret_num_devices;
    cl_uint ret_num_platforms;
    printf("=========第一步：选择平台================\n");
    clGetPlatformIDs(0, NULL, &ret_num_platforms);
    printf("可用平台个数: %u \n", (unsigned int)ret_num_platforms);
    //根据平台个数分配平台数组
    cl_platform_id* platforms_list = (cl_platform_id*)malloc(sizeof(cl_platform_id) * ret_num_platforms);
    clGetPlatformIDs(ret_num_platforms, platforms_list, NULL);

    uint32_t name_size = 0;
    for (int i = 0; i < ret_num_platforms; i++)
    {   
        clGetPlatformInfo(platforms_list[i], CL_PLATFORM_NAME, 0, NULL, &name_size);
        char* paltform_name = (char*)malloc(sizeof(char) * name_size);
        clGetPlatformInfo(platforms_list[i], CL_PLATFORM_NAME, name_size, (void*)paltform_name, NULL);
        printf("平台%d:  %s \n",i, paltform_name);
        free(paltform_name);
    }
    int p_id = 0;
    printf("选择平台 = %d \n", p_id);
    cl_platform_id platform = platforms_list[p_id];
    free(platforms_list);
    printf("\n=========第二步：选择设备================\n");
    uint32_t device_gpu_number = 0;
    uint32_t device_cpu_number = 0;
    clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 0, NULL, &device_gpu_number);
    printf("找到GPU设备数: %u \n", device_gpu_number);
    cl_device_id* Device_list = (cl_device_id*)malloc(sizeof(cl_device_id) * device_gpu_number);
    clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, device_gpu_number, Device_list, NULL);

    uint32_t device_name_size;
    for (int i = 0; i < device_gpu_number; i++)
    {
        clGetDeviceInfo(Device_list[i], CL_DEVICE_NAME, 0, NULL, &device_name_size);
        char* device_name = (char*)malloc(sizeof(char) * device_name_size);
        clGetDeviceInfo(Device_list[i], CL_DEVICE_NAME, device_name_size, (void*)device_name, NULL);
        printf("GPU设备%d: %s \n", i, device_name);
    }
    clGetDeviceIDs(platform, CL_DEVICE_TYPE_CPU, 0, NULL, &device_cpu_number);
    printf("找到CPU设备数: %u \n", device_cpu_number);
    if (device_cpu_number > 0) {
        cl_device_id* Device_cpu_list = (cl_device_id*)malloc(sizeof(cl_device_id) * device_cpu_number);
        clGetDeviceIDs(platform, CL_DEVICE_TYPE_CPU, device_cpu_number, Device_cpu_list, NULL);
    }

    printf("\n=========第三步：创建上下文================\n");
    cl_context Context = clCreateContext(NULL, 1, Device_list, NULL, NULL, NULL);
    if (Context == NULL) {
        printf("创建上下文失败\n");
        exit(-1);
    }
    printf("\n=========第四步：创建命令队列================\n");
    cl_command_queue command_queue = clCreateCommandQueue(Context, Device_list[0], 0, NULL);
    if (command_queue == NULL) {
        printf("创建命令队列失败\n");
        exit(-1);
    }
    printf("\n=========第五步：创建程序对象================\n");
    char* source = ConvertToString("matrix.cl");
    size_t source_size = strlen(source);
    const char* temp_src = source;
    const char** input = &temp_src;
    printf("len = %d \nsource = %s \n",source_size,source);
    cl_program program = clCreateProgramWithSource(Context, 1, input, &source_size, NULL);
    if (program == NULL) {
        printf("创建程序对象失败");
        exit(-1);
    }

    printf("\n=========第六步：编译程序================\n");
    if (CL_SUCCESS != clBuildProgram(program, 1, Device_list, NULL, NULL, NULL)) {
        printf("编译程序错误 \n");
        char buidlog[4096];
        clGetProgramBuildInfo(program, Device_list[0], CL_PROGRAM_BUILD_LOG, sizeof(buidlog),buidlog,NULL);
        printf("错误原因: %s \n", buidlog);
        exit(-1);
    }
    printf("\n=========第七步：创建输入输出内存对象================\n");
    cl_mem mem_A = clCreateBuffer(
        Context,
        CL_MEM_READ_ONLY,
        MATRIX_MEM_SIZE,
        NULL,
        NULL
    );
    cl_mem mem_temp = clCreateBuffer(
        Context,
        CL_MEM_READ_WRITE,
        MATRIX_MEM_SIZE,
        NULL,
        NULL
    );
    cl_mem mem_Result = clCreateBuffer(
        Context,
        CL_MEM_WRITE_ONLY,
        MATRIX_MEM_SIZE,
        NULL,
        NULL
    );
    clEnqueueWriteBuffer(command_queue, mem_A, CL_TRUE, 0,
                            MATRIX_MEM_SIZE , A, 0, NULL, NULL);
    clEnqueueWriteBuffer(command_queue, mem_temp, CL_TRUE, 0,
                            MATRIX_MEM_SIZE, temp, 0, NULL, NULL);
    clEnqueueWriteBuffer(command_queue, mem_Result, CL_TRUE, 0,
                            MATRIX_MEM_SIZE , result, 0, NULL, NULL);

    printf("\n=========第八步：创建内核对象================\n");
    cl_kernel kernel = clCreateKernel(
        program,
        "matrix",
        NULL
    );
    if (kernel == NULL) {
        printf("创建内核对象失败\n");
        exit(-1);
    }
    printf("\n=========第九步：设置内核参数================\n");
    size_t global_item_size = 512;         // Process the entire lists
    size_t local_item_size = 512;          // Divide work items into groups of 1
    int times = 31;
    int raw_n = MATRIX_SIZE / global_item_size;
    clSetKernelArg(kernel, 0, sizeof(cl_mem), (void*)&mem_A);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), (void*)&mem_temp);
    clSetKernelArg(kernel, 2, sizeof(cl_mem), (void*)&mem_Result);
    clSetKernelArg(kernel, 3, sizeof(int),    (void*)&times);
    clSetKernelArg(kernel, 4, sizeof(int), (void*)&raw_n);
    clock_t start = clock();

    printf("\n=========第十步：执行内核================\n");
    clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL,
                             &global_item_size, &local_item_size, 0, NULL, NULL);

    printf("\n=========第十一步：读取结果================\n");
    if (CL_SUCCESS != clEnqueueReadBuffer(command_queue, mem_Result, CL_TRUE, 0,
        MATRIX_MEM_SIZE, result, 0, NULL, NULL)) {
        printf("read buffer failed \n");
    }
    clock_t end = clock();
    printf("Result = %f \n", result[0]);
    CHECK_MATRIX(result, 500);
    printf("耗时= %ld ms \n",(end-start));
    printf("\n=========第十二步：释放资源================\n");
    clFlush(command_queue);
    clFinish(command_queue);
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseMemObject(mem_A);
    clReleaseMemObject(mem_Result);
    clReleaseCommandQueue(command_queue);
    clReleaseContext(Context);

}