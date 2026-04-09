BeginPackage["NLopt`"]


NLoptMinimize::usage = "NLoptMinimize[expr, vars, x0Matrix, opts] 
provides a fast multi-start global optimization using NLopt.
opts: 
{
  Inequalities -> {},  e.g. {x^2+y^2 <= 1}
  Equalities -> {},    e.g. {x == y}
  Bounds -> {},        e.g. {{x, -5, 5}, {y, 0, 10}}
  Algorithm -> 25,     LN_COBYLA, 25,34,28,29,35,19,1
  Tolerance -> 10^-16,
  MaxIterations -> 1000
}
";

(* 导出选项名，防止用户输入时变成全局变量 *)
(* 影响不大，不必管他 *)
(*Inequalities::usage = "Option for NLoptMinimize";
Equalities::usage = "Option for NLoptMinimize";
Bounds::usage = "Option for NLoptMinimize";
Algorithm::usage = "Option for NLoptMinimize";
Tolerance::usage = "Option for NLoptMinimize";
MaxIterations::usage = "Option for NLoptMinimize";*)


Begin["`Private`"]


(* 动态获取路径 *)
$PackageDir = 
If[
	$InputFileName =!= "",
	DirectoryName@$InputFileName,
	NotebookDirectory[]
];

(* 检查 DLL 是否存在，如果不存在提醒用户运行 compile.wl *)
$DllPath = FileNameJoin[{$PackageDir, "nlopt_math_multi.dll"}];
If[!FileExistsQ[$DllPath], 
  Print["Warning: nlopt_math_multi.dll not found. Please run Compile.wl first."];
];

(* 加载环境与库 *)
SetEnvironment["PATH" -> $PackageDir <> ";" <> Environment["PATH"]];

nloptLinkMulti = LibraryFunctionLoad[$DllPath, "run_nlopt_multi",
   {"UTF8String", "UTF8String", "UTF8String", {Real, 1, "Shared"}, {Real, 1, "Shared"}, {Real, 1, "Shared"}, {Real, 2, "Shared"}},
   {Real, 2}
];


(* 表达式转换器 *)
ToTEString[expr_] := Module[{str},
  str = ToString[expr, InputForm];
  StringReplace[str, {"[" -> "(", "]" -> ")", "Sin" -> "sin", "Cos" -> "cos",
   "Tan" -> "tan", "Exp" -> "exp", "Log" -> "log", "Sqrt" -> "sqrt", 
   "Abs" -> "abs", "Pi" -> "pi", "E" -> "e"}]
];


(* 全局优化包装函数 *)
Options[NLoptMinimize] = {
  Inequalities -> {}, (* 例如: {x^2+y^2 <= 1} *)
  Equalities -> {},   (* 例如: {x == y} *)
  Bounds -> {},       (* 例如: {{x, -5, 5}, {y, 0, 10}} *)
  Algorithm -> 25,    (* 25 是 LN_COBYLA (支持约束的无梯度算法) *)
  Tolerance -> 10^-16,
  MaxIterations -> 1000
};

(* 
关于选项 Algorithm：
  "LN_COBYLA" -> 25,     (* 支持约束，局部默认 *)
  "LN_BOBYQA" -> 34,     (* 无约束/仅边界约束王者 *)
  "LN_NELDERMEAD" -> 28, (* 经典单纯形法 *)
  "LN_SBPLX" -> 29,      (* 改进型单纯形法 *)
  "GN_ISRES" -> 35,      (* 支持约束的全局进化算法 *)
  "GN_CRS2_LM" -> 19,    (* 优秀的全局随机搜索 *)
  "GN_DIRECT_L" -> 1     (* 确定性全局搜索 *)
  
支持\[OpenCurlyDoubleQuote]非线性约束\[CloseCurlyDoubleQuote]的算法（如果用了 Inequalities 或 Equalities）
25 (LN_COBYLA)：局部优化。最推荐的默认算法！它是 NLopt 中极少数既不需要导数，又完美支持非线性不等式和等式约束的算法。非常稳定。
35 (GN_ISRES)：全局优化。一种进化启发式算法。支持非线性约束，但强制要求你必须为所有变量提供明确的上下界（Bounds）。

不带约束，或只有\[OpenCurlyDoubleQuote]边界约束\[CloseCurlyDoubleQuote]的算法（速度更快，精度更高）
如果只设置了 Bounds，没有设置非线性约束（即 Inequalities->{}），建议改用下面这些速度极快的算法：

34 (LN_BOBYQA)：局部优化。在有边界约束的情况下，它是无导数算法里的王者，收敛速度和精度远超 COBYLA。
28 (LN_NELDERMEAD)：局部优化。大名鼎鼎的单纯形法，非常经典，鲁棒性好。
29 (LN_SBPLX)：局部优化。Nelder-Mead 的增强版（Subplex），在处理高维问题时比单纯形法更可靠。
19 (GN_CRS2_LM)：全局优化。带局部变异的受控随机搜索。在给定边界内寻找全局极小值，效果极佳。
1 (GN_DIRECT_L)：全局优化。基于空间分割的确定性全局算法，必须提供明确的边界。
*)

NLoptMinimize[expr_, vars_List, x0Matrix_?MatrixQ, OptionsPattern[]] := Module[
  {nVars, numPoints, varRules, objStr, ineqStr, eqStr, lb, ub, optsArr, rawRes, bestRow},
  
  nVars = Length[vars];
  numPoints = Length[x0Matrix];
  varRules = Thread[vars -> Table[Symbol["x" <> ToString[i]], {i, nVars}]];
  
  (* 1. 转换目标函数 *)
  objStr = ToTEString[expr /. varRules];
  
  (* 2. 处理不等式 f(x) <= 0 (提取左边减右边) *)
  ineqStr = StringRiffle[ToTEString[(#[[1]] - #[[2]]) /. varRules] & /@ OptionValue[Inequalities], "|"];
  
  (* 3. 处理等式 h(x) == 0 *)
  eqStr = StringRiffle[ToTEString[(#[[1]] - #[[2]]) /. varRules] & /@ OptionValue[Equalities], "|"];
  
  (* 4. 处理边界条件 *)
  lb = ConstantArray[-10^6, nVars]; (* 默认无下界 *)
  ub = ConstantArray[10^6, nVars];  (* 默认无上界 *)
  Scan[(
    lb[[ Position[vars, #[[1]]][[1, 1]] ]] = #[[2]];
    ub[[ Position[vars, #[[1]]][[1, 1]] ]] = #[[3]];
  )&, OptionValue[Bounds]];
  
  (* 5. 选项配置数组 *)
  optsArr = {OptionValue[Algorithm], OptionValue[Tolerance], OptionValue[MaxIterations]} // N;
  
  (* 6. 调用 C 底层并行处理 *)
  rawRes = nloptLinkMulti[objStr, ineqStr, eqStr, 
   Developer`ToPackedArray[N@lb],
   Developer`ToPackedArray[N@ub], 
   Developer`ToPackedArray[N@optsArr], 
   Developer`ToPackedArray[N@x0Matrix]
   ];
  
  (* 7. 挑选出最好的结果 (按目标函数值从小到大排序，状态码 > 0 代表收敛) *)
  (* 过滤掉未收敛(状态<0)的，如果都未收敛则返回所有 *)
  bestRow = First[SortBy[Select[rawRes, #[[1]] >= 0 &], #[[2]] &], First[SortBy[rawRes, #[[2]] &]]];
  
  (* 返回格式: {全局极小值, {变量解}, 状态码, 所有的测试结果(供分析)} *)
  <|
    "GlobalMinimum" -> bestRow[[2]],
    "BestSolution" -> Thread[vars -> bestRow[[3 ;; ]]],
    "StatusCode" -> bestRow[[1]],
    "AllResultsMatrix" -> rawRes (* 可以用这个分析局部极小值的分布 *)
  |>
];

SyntaxInformation[NLoptMinimize] = {"ArgumentsPattern"->{_,OptionsPattern[]}};


End[]


EndPackage[]
