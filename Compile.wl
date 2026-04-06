(* ::Package:: *)

Needs["CCompilerDriver`"]

workDir = 
If[
	$InputFileName =!= "", 
	DirectoryName[$InputFileName], 
	NotebookDirectory[]
];

SetEnvironment["PATH" -> FileNameJoin[{workDir, "vendor", "nlopt_precompiled", "bin"}] <> ";" <> Environment["PATH"]];


(* \:53ef\:80fd\:63d0\:793a
 CreateLibrary::snfnd: File nlopt_math_multi.lib not generated. Check whether the corresponding DLL exports any symbols.
CreateLibrary::snfnd: File nlopt_math_multi.exp not generated. Check whether the corresponding DLL exports any symbols.
\:4e0d\:5fc5\:7ba1\:4ed6
*)
lib = CreateLibrary[
  {FileNameJoin[{workDir, "src", "nlopt_link.c"}], FileNameJoin[{workDir, "src", "tinyexpr.c"}]},
  "nlopt_math_multi",
  "IncludeDirectories" -> {FileNameJoin[{workDir, "vendor", "nlopt_precompiled", "include"}], FileNameJoin[{workDir, "src"}]},
  "LibraryDirectories" -> {FileNameJoin[{workDir, "vendor", "nlopt_precompiled", "lib"}]},
  "Libraries" -> {"nlopt"}, 
  "TargetDirectory" -> workDir
];

Remove[{workDir,lib}]
