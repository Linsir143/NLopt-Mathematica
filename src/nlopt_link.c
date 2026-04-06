#include "WolframLibrary.h"
#include "nlopt.h"
#include "tinyexpr.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#if defined(_WIN32) || defined(__WIN32__) || defined(_WIN64)
#define MY_EXPORT __declspec(dllexport)
#else
#define MY_EXPORT __attribute__((visibility("default")))
#endif

// 约束数据结构
typedef struct {
    te_expr *expr;
    double *te_vars;
} ConstraintData;

// 目标函数
double myfunc(unsigned n, const double *x, double *grad, void *d) {
    ConstraintData *data = (ConstraintData *)d;
    if (grad) {} // COBYLA 无需梯度
    for (unsigned i = 0; i < n; ++i) data->te_vars[i] = x[i];
    return te_eval(data->expr);
}

// 不等式约束函数 (NLopt 要求 f(x) <= 0)
double ineq_func(unsigned n, const double *x, double *grad, void *d) {
    ConstraintData *data = (ConstraintData *)d;
    if (grad) {}
    for (unsigned i = 0; i < n; ++i) data->te_vars[i] = x[i];
    return te_eval(data->expr);
}

// 等式约束函数 (NLopt 要求 h(x) == 0)
double eq_func(unsigned n, const double *x, double *grad, void *d) {
    ConstraintData *data = (ConstraintData *)d;
    if (grad) {}
    for (unsigned i = 0; i < n; ++i) data->te_vars[i] = x[i];
    return te_eval(data->expr);
}

// 辅助函数：安全复制字符串
char* my_strdup(const char* s) {
    char* copy = (char*)malloc(strlen(s) + 1);
    strcpy(copy, s);
    return copy;
}

MY_EXPORT mint WolframLibrary_getVersion() { return WolframLibraryVersion; }
MY_EXPORT int WolframLibrary_initialize(WolframLibraryData libData) { return LIBRARY_NO_ERROR; }
MY_EXPORT void WolframLibrary_uninitialize(WolframLibraryData libData) {}

/*
 * 新版接口参数：
 * Args[0]: 目标函数字符串
 * Args[1]: 不等式约束字符串 (以 '|' 分隔，f(x)<=0)
 * Args[2]: 等式约束字符串 (以 '|' 分隔，h(x)==0)
 * Args[3]: Lower bounds {Real, 1}
 * Args[4]: Upper bounds {Real, 1}
 * Args[5]: Options {algo_id, xtol_rel, maxeval} {Real, 1}
 * Args[6]: 初始点矩阵 x0_matrix {Real, 2}
 */
MY_EXPORT int run_nlopt_multi(WolframLibraryData libData, mint Argc, MArgument *Args, MArgument Res) {
    // 1. 获取参数
    char *obj_str  = MArgument_getUTF8String(Args[0]);
    char *ineq_str = MArgument_getUTF8String(Args[1]);
    char *eq_str   = MArgument_getUTF8String(Args[2]);
    
    double *lb = libData->MTensor_getRealData(MArgument_getMTensor(Args[3]));
    double *ub = libData->MTensor_getRealData(MArgument_getMTensor(Args[4]));
    double *opts = libData->MTensor_getRealData(MArgument_getMTensor(Args[5]));
    
    MTensor x0_tensor = MArgument_getMTensor(Args[6]);
    mint const *dims = libData->MTensor_getDimensions(x0_tensor);
    int num_points = (int)dims[0];
    int n_vars     = (int)dims[1];
    double *x0_mat = libData->MTensor_getRealData(x0_tensor);

    // 解析配置
    nlopt_algorithm algo = (nlopt_algorithm)((int)opts[0]);
    double xtol_rel = opts[1];
    int maxeval = (int)opts[2];

    // 2. 设置 TinyExpr 变量
    te_variable *vars = (te_variable *)malloc(n_vars * sizeof(te_variable));
    double *te_vars = (double *)malloc(n_vars * sizeof(double));
    for (int i = 0; i < n_vars; ++i) {
        char name[16];
        sprintf(name, "x%d", i + 1);
        vars[i].name = my_strdup(name);
        vars[i].address = &te_vars[i];
        vars[i].type = TE_VARIABLE;
        vars[i].context = 0;
    }

    // 3. 编译表达式
    int err;
    te_expr *obj_expr = te_compile(obj_str, vars, n_vars, &err);
    ConstraintData obj_data = {obj_expr, te_vars};

    // 解析并编译约束 (以 | 分隔)
    te_expr *ineq_exprs[50]; int num_ineq = 0;
    if (strlen(ineq_str) > 0) {
        char *str_copy = my_strdup(ineq_str);
        char *tok = strtok(str_copy, "|");
        while(tok && num_ineq < 50) {
            ineq_exprs[num_ineq++] = te_compile(tok, vars, n_vars, &err);
            tok = strtok(NULL, "|");
        }
        free(str_copy);
    }

    te_expr *eq_exprs[50]; int num_eq = 0;
    if (strlen(eq_str) > 0) {
        char *str_copy = my_strdup(eq_str);
        char *tok = strtok(str_copy, "|");
        while(tok && num_eq < 50) {
            eq_exprs[num_eq++] = te_compile(tok, vars, n_vars, &err);
            tok = strtok(NULL, "|");
        }
        free(str_copy);
    }

    // 4. 准备输出张量 (num_points 行, n_vars + 2 列: [状态码, 最小值, x1, x2...])
    MTensor res_tensor;
    mint out_dims[2] = {num_points, n_vars + 2};
    libData->MTensor_new(MType_Real, 2, out_dims, &res_tensor);
    double *res_data = libData->MTensor_getRealData(res_tensor);

    // 5. C 语言底层的极速循环 (Multi-start 核心)
    double *x_curr = (double *)malloc(n_vars * sizeof(double));
    ConstraintData *ineq_data = (ConstraintData *)malloc(num_ineq * sizeof(ConstraintData));
    ConstraintData *eq_data = (ConstraintData *)malloc(num_eq * sizeof(ConstraintData));

    for (int p = 0; p < num_points; p++) {
        // 创建优化器实例
        nlopt_opt opt = nlopt_create(algo, n_vars);
        nlopt_set_lower_bounds(opt, lb);
        nlopt_set_upper_bounds(opt, ub);
        nlopt_set_min_objective(opt, myfunc, &obj_data);
        
        // 添加约束
        for(int i = 0; i < num_ineq; i++) {
            ineq_data[i].expr = ineq_exprs[i]; ineq_data[i].te_vars = te_vars;
            nlopt_add_inequality_constraint(opt, ineq_func, &ineq_data[i], 1e-6);
        }
        for(int i = 0; i < num_eq; i++) {
            eq_data[i].expr = eq_exprs[i]; eq_data[i].te_vars = te_vars;
            nlopt_add_equality_constraint(opt, eq_func, &eq_data[i], 1e-6);
        }
        
        nlopt_set_xtol_rel(opt, xtol_rel);
        if (maxeval > 0) nlopt_set_maxeval(opt, maxeval);

        // 获取当前行的初始点
        for(int j = 0; j < n_vars; j++) x_curr[j] = x0_mat[p * n_vars + j];

        // 运行优化
        double minf = 0.0;
        nlopt_result status = nlopt_optimize(opt, x_curr, &minf);

        // 保存结果到输出矩阵
        int row_idx = p * (n_vars + 2);
        res_data[row_idx + 0] = (double)status; // 记录状态码 (负数是失败，正数是成功)
        res_data[row_idx + 1] = minf;           // 极小值
        for(int j = 0; j < n_vars; j++) {
            res_data[row_idx + 2 + j] = x_curr[j]; // 最优解变量
        }

        nlopt_destroy(opt);
    }

    // 6. 清理内存
    free(x_curr); free(ineq_data); free(eq_data);
    for(int i=0; i<num_ineq; i++) if(ineq_exprs[i]) te_free(ineq_exprs[i]);
    for(int i=0; i<num_eq; i++) if(eq_exprs[i]) te_free(eq_exprs[i]);
    te_free(obj_expr);
    for (int i = 0; i < n_vars; ++i) free((void*)vars[i].name);
    free(vars); free(te_vars);
    libData->UTF8String_disown(obj_str); libData->UTF8String_disown(ineq_str); libData->UTF8String_disown(eq_str);

    MArgument_setMTensor(Res, res_tensor);
    return LIBRARY_NO_ERROR;
}