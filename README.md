# NLopt-Mathematica (NLopt for Mathematica)

A high-performance global/local optimization wrapper for Wolfram Mathematica, powered by [NLopt](https://github.com/stevengj/nlopt) and [tinyexpr](https://github.com/codeplea/tinyexpr).

## Features
- **Lightning Fast**: Evaluates multi-start global optimizations directly in C, bypassing the Mathematica-to-C overhead.
- **Constraints Support**: Fully supports non-linear inequalities (`<=`) and equalities (`==`).
- **No Derivatives Needed**: Uses powerful derivative-free algorithms like COBYLA, BOBYQA, and Nelder-Mead.
- **Easy Setup**: Uses precompiled NLopt binaries for Windows. 

## Installation (Windows 64-bit)

1. Clone or download this repository.
2. Open `Compile.wl` in Mathematica and evaluate the script to build the LibraryLink DLL.
3. Load `NLopt.wl` to start optimizing!

Or install it in Mathematica with the following code:
```mathematica
PacletInstall["https://github.com/Linsir143/NLopt-Mathematica/releases/download/v1.0.0/NLopt-1.0.0.paclet"];
(*PacletObject[Name: NLopt
Version: 1.0.0]*)
```
Check if the installation was successful:
```
PacletFind["NLopt**"]
```
Test if it works properly:
```
<<NLopt`;
NLoptMinimize[(x^2+y^2+z^2)^2-3 (x^3 y+y^3 z+x z^3),{x,y,z},RandomReal[{-1,1},{10,3}],Equalities->{x+y+z==1}]
NLoptMinimize[(x^2+y^2+z^2)^2-3 (x^3 y+y^3 z+x z^3)/.z->1,{x,y},RandomReal[{-1,1},{10,2}]]
```
To uninstall:
```
PacletUninstall@PacletFind["NLopt"] 
```


## Quick Start

```mathematica
<< "NLopt.wl"

(* Objective function *)
objFunc = (x^2 + y^2) - 10 Cos[2 Pi x] - 10 Cos[2 Pi y] + 20;

(* Generate 1000 random starting points *)
randomPoints = RandomReal[{-5, 5}, {1000, 2}];

(* Run Global Optimization *)
result = NLoptMinimize[
  objFunc, 
  {x, y}, 
  randomPoints,
  Inequalities -> {x + y <= 1},
  Bounds -> {{x, -5, 5}, {y, -5, 5}},
  Algorithm -> 25 (* 25 = LN_COBYLA *)
]

result["BestSolution"]
