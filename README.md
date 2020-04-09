# YCMake

***WARNING: This project has moved to [https://git.yzena.com/][1] for [these
reasons][2].***

This project contains all of the CMake tools for Yzena repos. It is usually
included as a git submodule in other projects.

## Contents

Files:

	CMakeLists.txt     The CMake config file for this directory. It just
	                   includes all of the other CMake files in the directory
	                   and adds all subdirectories.
	functions.cmake    All CMake functions used in Yzena repositories.
	gen_data.cmake.in  Allows one function to generate data from source code.

[1]: https://git.yzena.com/Yzena/YCMake
[2]: https://gavinhoward.com/2020/04/i-am-moving-away-from-github/
