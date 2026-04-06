(* ::Package:: *)

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

(* \:5bfc\:51fa\:9009\:9879\:540d\:ff0c\:9632\:6b62\:7528\:6237\:8f93\:5165\:65f6\:53d8\:6210\:5168\:5c40\:53d8\:91cf *)
(* \:5f71\:54cd\:4e0d\:5927\:ff0c\:4e0d\:5fc5\:7ba1\:4ed6 *)
(*Inequalities::usage = "Option for NLoptMinimize";
Equalities::usage = "Option for NLoptMinimize";
Bounds::usage = "Option for NLoptMinimize";
Algorithm::usage = "Option for NLoptMinimize";
Tolerance::usage = "Option for NLoptMinimize";
MaxIterations::usage = "Option for NLoptMinimize";*)


Begin["`Private`"]


(* \:52a8\:6001\:83b7\:53d6\:8def\:5f84 *)
$PackageDir = 
If[
	$InputFileName =!= "",
	DirectoryName@$InputFileName,
	NotebookDirectory[]
];

(* \:68c0\:67e5 DLL \:662f\:5426\:5b58\:5728\:ff0c\:5982\:679c\:4e0d\:5b58\:5728\:63d0\:9192\:7528\:6237\:8fd0\:884c compile.wl *)
$DllPath = FileNameJoin[{$PackageDir, "nlopt_math_multi.dll"}];
If[!FileExistsQ[$DllPath], 
  Print["Warning: nlopt_math_multi.dll not found. Please run Compile.wl first."];
];

(* \:52a0\:8f7d\:73af\:5883\:4e0e\:5e93 *)
SetEnvironment["PATH" -> $PackageDir <> ";" <> Environment["PATH"]];

nloptLinkMulti = LibraryFunctionLoad[$DllPath, "run_nlopt_multi",
   {"UTF8String", "UTF8String", "UTF8String", {Real, 1, "Shared"}, {Real, 1, "Shared"}, {Real, 1, "Shared"}, {Real, 2, "Shared"}},
   {Real, 2}
];


(* \:8868\:8fbe\:5f0f\:8f6c\:6362\:5668 *)
ToTEString[expr_] := Module[{str},
  str = ToString[expr, InputForm];
  StringReplace[str, {"[" -> "(", "]" -> ")", "Sin" -> "sin", "Cos" -> "cos",
   "Tan" -> "tan", "Exp" -> "exp", "Log" -> "log", "Sqrt" -> "sqrt", 
   "Abs" -> "abs", "Pi" -> "pi", "E" -> "e"}]
];


(* \:5168\:5c40\:4f18\:5316\:5305\:88c5\:51fd\:6570 *)
Options[NLoptMinimize] = {
  Inequalities -> {}, (* \:4f8b\:5982: {x^2+y^2 <= 1} *)
  Equalities -> {},   (* \:4f8b\:5982: {x == y} *)
  Bounds -> {},       (* \:4f8b\:5982: {{x, -5, 5}, {y, 0, 10}} *)
  Algorithm -> 25,    (* 25 \:662f LN_COBYLA (\:652f\:6301\:7ea6\:675f\:7684\:65e0\:68af\:5ea6\:7b97\:6cd5) *)
  Tolerance -> 10^-16,
  MaxIterations -> 1000
};

(* 
\:5173\:4e8e\:9009\:9879 Algorithm\:ff1a
  "LN_COBYLA" -> 25,     (* \:652f\:6301\:7ea6\:675f\:ff0c\:5c40\:90e8\:9ed8\:8ba4 *)
  "LN_BOBYQA" -> 34,     (* \:65e0\:7ea6\:675f/\:4ec5\:8fb9\:754c\:7ea6\:675f\:738b\:8005 *)
  "LN_NELDERMEAD" -> 28, (* \:7ecf\:5178\:5355\:7eaf\:5f62\:6cd5 *)
  "LN_SBPLX" -> 29,      (* \:6539\:8fdb\:578b\:5355\:7eaf\:5f62\:6cd5 *)
  "GN_ISRES" -> 35,      (* \:652f\:6301\:7ea6\:675f\:7684\:5168\:5c40\:8fdb\:5316\:7b97\:6cd5 *)
  "GN_CRS2_LM" -> 19,    (* \:4f18\:79c0\:7684\:5168\:5c40\:968f\:673a\:641c\:7d22 *)
  "GN_DIRECT_L" -> 1     (* \:786e\:5b9a\:6027\:5168\:5c40\:641c\:7d22 *)
  
\:652f\:6301\[OpenCurlyDoubleQuote]\:975e\:7ebf\:6027\:7ea6\:675f\[CloseCurlyDoubleQuote]\:7684\:7b97\:6cd5\:ff08\:5982\:679c\:7528\:4e86 Inequalities \:6216 Equalities\:ff09
25 (LN_COBYLA)\:ff1a\:5c40\:90e8\:4f18\:5316\:3002\:6700\:63a8\:8350\:7684\:9ed8\:8ba4\:7b97\:6cd5\:ff01\:5b83\:662f NLopt \:4e2d\:6781\:5c11\:6570\:65e2\:4e0d\:9700\:8981\:5bfc\:6570\:ff0c\:53c8\:5b8c\:7f8e\:652f\:6301\:975e\:7ebf\:6027\:4e0d\:7b49\:5f0f\:548c\:7b49\:5f0f\:7ea6\:675f\:7684\:7b97\:6cd5\:3002\:975e\:5e38\:7a33\:5b9a\:3002
35 (GN_ISRES)\:ff1a\:5168\:5c40\:4f18\:5316\:3002\:4e00\:79cd\:8fdb\:5316\:542f\:53d1\:5f0f\:7b97\:6cd5\:3002\:652f\:6301\:975e\:7ebf\:6027\:7ea6\:675f\:ff0c\:4f46\:5f3a\:5236\:8981\:6c42\:4f60\:5fc5\:987b\:4e3a\:6240\:6709\:53d8\:91cf\:63d0\:4f9b\:660e\:786e\:7684\:4e0a\:4e0b\:754c\:ff08Bounds\:ff09\:3002

\:4e0d\:5e26\:7ea6\:675f\:ff0c\:6216\:53ea\:6709\[OpenCurlyDoubleQuote]\:8fb9\:754c\:7ea6\:675f\[CloseCurlyDoubleQuote]\:7684\:7b97\:6cd5\:ff08\:901f\:5ea6\:66f4\:5feb\:ff0c\:7cbe\:5ea6\:66f4\:9ad8\:ff09
\:5982\:679c\:53ea\:8bbe\:7f6e\:4e86 Bounds\:ff0c\:6ca1\:6709\:8bbe\:7f6e\:975e\:7ebf\:6027\:7ea6\:675f\:ff08\:5373 Inequalities->{}\:ff09\:ff0c\:5efa\:8bae\:6539\:7528\:4e0b\:9762\:8fd9\:4e9b\:901f\:5ea6\:6781\:5feb\:7684\:7b97\:6cd5\:ff1a

34 (LN_BOBYQA)\:ff1a\:5c40\:90e8\:4f18\:5316\:3002\:5728\:6709\:8fb9\:754c\:7ea6\:675f\:7684\:60c5\:51b5\:4e0b\:ff0c\:5b83\:662f\:65e0\:5bfc\:6570\:7b97\:6cd5\:91cc\:7684\:738b\:8005\:ff0c\:6536\:655b\:901f\:5ea6\:548c\:7cbe\:5ea6\:8fdc\:8d85 COBYLA\:3002
28 (LN_NELDERMEAD)\:ff1a\:5c40\:90e8\:4f18\:5316\:3002\:5927\:540d\:9f0e\:9f0e\:7684\:5355\:7eaf\:5f62\:6cd5\:ff0c\:975e\:5e38\:7ecf\:5178\:ff0c\:9c81\:68d2\:6027\:597d\:3002
29 (LN_SBPLX)\:ff1a\:5c40\:90e8\:4f18\:5316\:3002Nelder-Mead \:7684\:589e\:5f3a\:7248\:ff08Subplex\:ff09\:ff0c\:5728\:5904\:7406\:9ad8\:7ef4\:95ee\:9898\:65f6\:6bd4\:5355\:7eaf\:5f62\:6cd5\:66f4\:53ef\:9760\:3002
19 (GN_CRS2_LM)\:ff1a\:5168\:5c40\:4f18\:5316\:3002\:5e26\:5c40\:90e8\:53d8\:5f02\:7684\:53d7\:63a7\:968f\:673a\:641c\:7d22\:3002\:5728\:7ed9\:5b9a\:8fb9\:754c\:5185\:5bfb\:627e\:5168\:5c40\:6781\:5c0f\:503c\:ff0c\:6548\:679c\:6781\:4f73\:3002
1 (GN_DIRECT_L)\:ff1a\:5168\:5c40\:4f18\:5316\:3002\:57fa\:4e8e\:7a7a\:95f4\:5206\:5272\:7684\:786e\:5b9a\:6027\:5168\:5c40\:7b97\:6cd5\:ff0c\:5fc5\:987b\:63d0\:4f9b\:660e\:786e\:7684\:8fb9\:754c\:3002
*)

NLoptMinimize[expr_, vars_List, x0Matrix_?MatrixQ, OptionsPattern[]] := Module[
  {nVars, numPoints, varRules, objStr, ineqStr, eqStr, lb, ub, optsArr, rawRes, bestRow},
  
  nVars = Length[vars];
  numPoints = Length[x0Matrix];
  varRules = Thread[vars -> Table[Symbol["x" <> ToString[i]], {i, nVars}]];
  
  (* 1. \:8f6c\:6362\:76ee\:6807\:51fd\:6570 *)
  objStr = ToTEString[expr /. varRules];
  
  (* 2. \:5904\:7406\:4e0d\:7b49\:5f0f f(x) <= 0 (\:63d0\:53d6\:5de6\:8fb9\:51cf\:53f3\:8fb9) *)
  ineqStr = StringRiffle[ToTEString[(#[[1]] - #[[2]]) /. varRules] & /@ OptionValue[Inequalities], "|"];
  
  (* 3. \:5904\:7406\:7b49\:5f0f h(x) == 0 *)
  eqStr = StringRiffle[ToTEString[(#[[1]] - #[[2]]) /. varRules] & /@ OptionValue[Equalities], "|"];
  
  (* 4. \:5904\:7406\:8fb9\:754c\:6761\:4ef6 *)
  lb = ConstantArray[-10^6, nVars]; (* \:9ed8\:8ba4\:65e0\:4e0b\:754c *)
  ub = ConstantArray[10^6, nVars];  (* \:9ed8\:8ba4\:65e0\:4e0a\:754c *)
  Scan[(
    lb[[ Position[vars, #[[1]]][[1, 1]] ]] = #[[2]];
    ub[[ Position[vars, #[[1]]][[1, 1]] ]] = #[[3]];
  )&, OptionValue[Bounds]];
  
  (* 5. \:9009\:9879\:914d\:7f6e\:6570\:7ec4 *)
  optsArr = {OptionValue[Algorithm], OptionValue[Tolerance], OptionValue[MaxIterations]} // N;
  
  (* 6. \:8c03\:7528 C \:5e95\:5c42\:5e76\:884c\:5904\:7406 *)
  rawRes = nloptLinkMulti[objStr, ineqStr, eqStr, 
   Developer`ToPackedArray[N@lb],
   Developer`ToPackedArray[N@ub], 
   Developer`ToPackedArray[N@optsArr], 
   Developer`ToPackedArray[N@x0Matrix]
   ];
  
  (* 7. \:6311\:9009\:51fa\:6700\:597d\:7684\:7ed3\:679c (\:6309\:76ee\:6807\:51fd\:6570\:503c\:4ece\:5c0f\:5230\:5927\:6392\:5e8f\:ff0c\:72b6\:6001\:7801 > 0 \:4ee3\:8868\:6536\:655b) *)
  (* \:8fc7\:6ee4\:6389\:672a\:6536\:655b(\:72b6\:6001<0)\:7684\:ff0c\:5982\:679c\:90fd\:672a\:6536\:655b\:5219\:8fd4\:56de\:6240\:6709 *)
  bestRow = First[SortBy[Select[rawRes, #[[1]] >= 0 &], #[[2]] &], First[SortBy[rawRes, #[[2]] &]]];
  
  (* \:8fd4\:56de\:683c\:5f0f: {\:5168\:5c40\:6781\:5c0f\:503c, {\:53d8\:91cf\:89e3}, \:72b6\:6001\:7801, \:6240\:6709\:7684\:6d4b\:8bd5\:7ed3\:679c(\:4f9b\:5206\:6790)} *)
  <|
    "GlobalMinimum" -> bestRow[[2]],
    "BestSolution" -> Thread[vars -> bestRow[[3 ;; ]]],
    "StatusCode" -> bestRow[[1]],
    "AllResultsMatrix" -> rawRes (* \:53ef\:4ee5\:7528\:8fd9\:4e2a\:5206\:6790\:5c40\:90e8\:6781\:5c0f\:503c\:7684\:5206\:5e03 *)
  |>
];

SyntaxInformation[NLoptMinimize] = {"ArgumentsPattern"->{_,OptionsPattern[]}};


End[]


EndPackage[]
