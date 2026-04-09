(*  一个例子  *)
(* 我们来优化一个充满局部极小值的复杂函数：Rastrigin 或 简单的波浪函数 *)
objFunc = (x^2 + y^2) - 10 Cos[2 Pi x] - 10 Cos[2 Pi y] + 20;

(* 生成 1000 个在 [-5, 5] 区域内的随机初始点矩阵 *)
randomPoints = RandomReal[{-5, 5}, {1000, 2}];

(* 瞬间执行 1000 次受约束的局部优化，寻找全局最优！ *)
result = NLoptMinimize[
  objFunc, 
  {x, y}, 
  randomPoints,
  (* 添加复杂约束 *)
  Inequalities -> {x + y <= 1},    (* 线性约束 *)
  Equalities -> {},
  Bounds -> {{x, -5, 5}, {y, -5, 5}}, (* 边界约束 *)
  Algorithm -> 25,
  Tolerance -> 10^-8
]//EchoTiming;
(*0.189129*)

result // Short[#,50]&

(* 使用内置函数 FindMinimum  *)
result = 
FindMinimum[{objFunc, x + y <= 1},
{x,#1,-5,5},{y,#2,-5,5},
 PrecisionGoal -> 10^-8,
 Method -> Automatic
]&@@@randomPoints//EchoTiming;

result // Short[#,50]&

(*19.6675*)

(* 但是 FindMinimum 支持高精度计算，能够获得能恢复成精确代数数的数值,
不需要很高精度情况下可以考虑使用 nlopt 库做优化 *)
