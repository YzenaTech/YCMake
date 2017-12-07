# YCMake

This project contains all of the CMake tools for Yzena repos. It is usually
included as a git submodule in other projects.

## License

Because some code in the repository comes from the
[MySQL repo](https://github.com/mysql/mysql-server), and is licensed under the
GNU General Public License, Version 2, all code in the repository is under that
same license.

## Contents

Files:

	CMakeLists.txt   The CMake config file for this directory. It just includes
	                 all of the other CMake files in the directory and adds all
	                 subdirectories.
	functions.cmake  All CMake functions used in Yzena repositories.
	LICENSE.md       A Markdown version of the GNU General Public License,
	                 Version 2.
