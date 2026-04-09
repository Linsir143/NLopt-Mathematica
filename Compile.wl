Needs["CCompilerDriver`"]

workDir = 
If[
	$InputFileName =!= "", 
	DirectoryName[$InputFileName], 
	NotebookDirectory[]
];

SetEnvironment["PATH" -> FileNameJoin[{workDir, "vendor", "nlopt_precompiled", "bin"}] <> ";" <> Environment["PATH"]];


(* 可能提示
 CreateLibrary::snfnd: File nlopt_math_multi.lib not generated. Check whether the corresponding DLL exports any symbols.
CreateLibrary::snfnd: File nlopt_math_multi.exp not generated. Check whether the corresponding DLL exports any symbols.
不必管他
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
