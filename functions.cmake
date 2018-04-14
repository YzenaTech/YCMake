#	***** BEGIN LICENSE BLOCK *****
#
#	Copyright 2017 Yzena Tech
#
#	Licensed under the Apache License, Version 2.0 (the "Apache License")
#	with the following modification; you may not use this file except in
#	compliance with the Apache License and the following modification to it:
#	Section 6. Trademarks. is deleted and replaced with:
#
#	6. Trademarks. This License does not grant permission to use the trade
#		names, trademarks, service marks, or product names of the Licensor
#		and its affiliates, except as required to comply with Section 4(c) of
#		the License and to reproduce the content of the NOTICE file.
#
#	You may obtain a copy of the Apache License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the Apache License with the above modification is
#	distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#	KIND, either express or implied. See the Apache License for the specific
#	language governing permissions and limitations under the Apache License.
#
#	The function merge_static_libs() is also under the following copyright and
#	license:
#
#	Copyright (C) 2012 Modelon AB
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the BSD style license.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	FMILIB_License.txt file for more details.
#
#	You should have received a copy of the BSD license  along with this program.
#	If not, contact Modelon AB <http://www.modelon.com>.
#
#	****** END LICENSE BLOCK ******

# Make sure we save this.
set(SCRIPT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE INTERNAL "Directory of the merge script")
set(STATIC_LIBS_LIST "${STATIC_LIBS_LIST}" CACHE INTERNAL "List of libraries to merge")
set(STATIC_LIBS_NAMES "${STATIC_LIBS_NAMES}" CACHE INTERNAL "List of library target names")

set(FUNCTIONS_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "Directory of the functions.cmake file")

# For some reason, we get stupid CMake warnings.
cmake_policy(SET CMP0026 NEW)

# Generates a C file with a char array that contains the contents of a file,
# which can then be used as a string in C source. This is useful, for example,
# to turn OpenGL shaders, which should be in their own files, into C strings
# contained with source files that can then be compiled and inserted into an
# executable.
# Params: infile is the input file (the file that will be a turned into a char
# array; outfile is the output file (the file with the C array); array_name is
# the name of the array; target is the CMake target that other targets can then
# depend on; and start_line is the line in infile that will be the first line
# in the array, which is useful for excluding header comments.
function(create_data_target infile outfile array_name target start_line cstr)

	set(script "${CMAKE_CURRENT_BINARY_DIR}/${target}_script.cmake")

	configure_file("${FUNCTIONS_DIR}/gen_array.cmake.in" "${script}" @ONLY)

	add_custom_command(OUTPUT "${outfile}" COMMAND "${CMAKE_COMMAND}" -P "${script}")
	add_custom_target("${target}_script" DEPENDS "${outfile}")

	add_library("${target}" "${outfile}")
	add_dependencies("${target}" "${target}_script")

endfunction(create_data_target)

# Creates a symlink named "link" that points to "target".
function(create_symlink link target)
	add_custom_target("${link}" ALL COMMAND "${CMAKE_COMMAND}" -E create_symlink "${target}" "${link}")
endfunction(create_symlink)

function(static_lib_path var lib_output_name)

	# Build the path.
	string(CONCAT LIB_PATH
		"${CMAKE_CURRENT_BINARY_DIR}/"
		"${CMAKE_STATIC_LIBRARY_PREFIX}"
		"${lib_output_name}"
		"${CMAKE_STATIC_LIBRARY_SUFFIX}")

	# Set the variable in parent scope.
	set("${var}" "${LIB_PATH}" PARENT_SCOPE)

endfunction(static_lib_path)

# Adds a library to the list to merge.
function(merge_lib name output)

	# Set the target name.
	list(APPEND STATIC_LIBS_NAMES "${name}")
	set(STATIC_LIBS_NAMES "${STATIC_LIBS_NAMES}" CACHE INTERNAL "List of library target names")

	# Get the path.
	static_lib_path(LIB_PATH "${output}")
	list(APPEND STATIC_LIBS_LIST "${LIB_PATH}")
	set(STATIC_LIBS_LIST "${STATIC_LIBS_LIST}" CACHE INTERNAL "List of libraries to merge")

endfunction(merge_lib)

# Merge_static_libs(outlib) merges all libs in STATIC_LIB_NAMES into a single
# static library named outlib.
function(merge_libs outlib)

	# Get the names of all libraries to link.
	set(link_libs ${ARGN})

	# Create a dummy file that the target will depend on
	set(dummyfile ${CMAKE_CURRENT_BINARY_DIR}/${outlib}_dummy.c)
	file(WRITE ${dummyfile} "// ${dummyfile}")

	# Add the output library.
	add_library(${outlib} STATIC ${dummyfile})
	static_lib_path(outfile "${outlib}")

	# Make sure all libs are static.
	foreach(lib ${STATIC_LIBS_NAMES})
		get_target_property(libtype ${lib} TYPE)
		if(NOT libtype STREQUAL "STATIC_LIBRARY")
			message(FATAL_ERROR "Merge_static_libs can only process static libraries")
		endif()
	endforeach()

	# If we are on a multiconfig build system...
	if(NOT"${CMAKE_CFG_INTDIR}" STREQUAL ".")

		# Generate a list for each config type.
		foreach(lib ${STATIC_LIBS_LIST})
			foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
				get_target_property("libfile_${CONFIG_TYPE}" ${lib} "LOCATION_${CONFIG_TYPE}")
				list(APPEND libfiles_${CONFIG_TYPE} ${libfile_${CONFIG_TYPE}})
			endforeach()
		endforeach()

		#  Dedup the lists.
		foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
			list(REMOVE_DUPLICATES libfiles_${CONFIG_TYPE})
			set(libfiles ${libfiles} ${libfiles_${CONFIG_TYPE}})
		endforeach()

	endif()

	# Just to be sure: cleanup from duplicates
	list(REMOVE_DUPLICATES STATIC_LIBS_LIST)
	set(STATIC_LIBS_LIST "${STATIC_LIBS_LIST}" CACHE INTERNAL "List of libraries to merge")

	# Now the easy part for MSVC and for MAC
	if(MSVC)
		# lib.exe does the merging of libraries just need to conver the list into string
		foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
			set(flags "")
			foreach(lib ${libfiles_${CONFIG_TYPE}})
				set(flags "${flags} ${lib}")
			endforeach()
			string(TOUPPER "STATIC_LIBRARY_FLAGS_${CONFIG_TYPE}" PROPNAME)
			set_target_properties(${outlib} PROPERTIES ${PROPNAME} "${flags}")
		endforeach()

	elseif(APPLE)

		# Use OSX's libtool to merge archives.

		# We can't handle multiconfigs.
		if(multiconfig)
			message(FATAL_ERROR "Multiple configurations are not supported")
		endif()

		# Get the location of the library.
		get_target_property(outfile ${outlib} LOCATION)

		# Add the libtool command to merge.
		add_custom_command(TARGET ${outlib} POST_BUILD
			COMMAND rm ${outfile}
			COMMAND /usr/bin/libtool -static -o ${outfile} ${STATIC_LIBS_LIST})

	else()

		# General UNIX - need to "ar -x" and then "ar -ru"

		# We can't handle multiconfigs.
		if(multiconfig)
			message(FATAL_ERROR "Multiple configurations are not supported")
		endif()

		# Loop over the files.
		list(LENGTH STATIC_LIBS_LIST len1)
		math(EXPR len2 "${len1} - 1")
		foreach(val RANGE ${len2})

			# Get the library and its name from the lists.
			list(GET STATIC_LIBS_LIST ${val} lib)
			list(GET STATIC_LIBS_NAMES ${val} name)

			# objlistfile will contain the list of object files for the library.
			set(objlistfile "${lib}.objlist")
			set(objlistfile2 "${objlistfile}2")
			set(objdir "${lib}.objdir")
			set(objlistcmake  "${objlistfile}.cmake")
			set(objtarget "${name}_target")

			# We only need to extract files once.
			if(${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/cmake.check_cache IS_NEWER_THAN ${objlistcmake})

				#---------------------------------
				# Create a file to run in CMake later.
				string(CONCAT file_content
					"# Extract object files from the library
					message(STATUS \"Extracting object files from ${lib}\")
					execute_process(COMMAND ${CMAKE_AR} -x ${lib}
						WORKING_DIRECTORY ${objdir})
					# save the list of object files
					execute_process(COMMAND find ${objdir} -type f
						OUTPUT_FILE ${objlistfile}
						WORKING_DIRECTORY ${objdir})")

				FILE(WRITE "${objlistcmake}" "${file_content}")
				#---------------------------------

				# Make sure the obj directory exists.
				file(MAKE_DIRECTORY "${objdir}")

			endif()

			# Add the created file above as a command to run.
			add_custom_command(
				OUTPUT "${objlistfile}"
				COMMAND ${CMAKE_COMMAND} -P ${objlistcmake}
				DEPENDS "${name}")

			# Copy the list. This is necessary to avoid some errors.
			add_custom_target("${objtarget}"
				COMMAND ${CMAKE_COMMAND} -E copy ${objlistfile} ${objlistfile2}
				DEPENDS "${objlistfile}"
				BYPRODUCTS "${objlistfile2}")

			# Add the files in the list of object files to the list of files.
			list(APPEND extrafiles "${objlistfile2}")

			# Add a dependency from the output lib to the one we're processing.
			add_dependencies("${outlib}" "${objtarget}" "${name}")

		endforeach()

		# Run the merge.
		add_custom_command(TARGET "${outlib}"
			POST_BUILD
			COMMAND ${CMAKE_AR} r ${outfile} `cat ${extrafiles}`
			COMMAND ${CMAKE_RANLIB} "${outfile}")

	endif()

	# Link the needed libraries.
	target_link_libraries("${outlib}" "${link_libs}")

	# Install the resulting library.
	install(TARGETS "${outlib}" ARCHIVE DESTINATION lib/)

endfunction(merge_libs)

function(create_test_target target)

	# Create an executable, link libs to it, and add it as a test.
	add_executable("${target}" "${target}.c")
	target_link_libraries("${target}" "${ARGN}")

endfunction(create_test_target)

function(create_test_from_target target test_num)
	add_test(NAME "${target}${test_num}" COMMAND "$<TARGET_FILE:${target}>" ${ARGN})
endfunction(create_test_from_target)

function(create_test target)
	create_test_target("${target}" "${ARGN}")
	add_test(NAME "${target}" COMMAND "$<TARGET_FILE:${target}>")
endfunction()

function(create_shared_library name output_name src doinstall)

	# Add the library and link its dependencies.
	add_library("${name}" SHARED "${src}")
	target_link_libraries("${name}" "${ARGN}")

	# Set its output name.
	set_target_properties("${name}"
		PROPERTIES
		OUTPUT_NAME "${output_name}")

	# Install it, if necessary.
	if(doinstall)
		install(TARGETS "${name}" LIBRARY DESTINATION lib/)
	endif(doinstall)

endfunction(create_shared_library)

function(create_static_library name output_name src doinstall)

	# Add the library and link its dependencies.
	add_library("${name}" STATIC "${src}")
	target_link_libraries("${name}" "${ARGN}")

	# Set its output name.
	set_target_properties("${name}"
		PROPERTIES
		OUTPUT_NAME "${output_name}")

	# Install it, if necessary.
	if(doinstall)
		install(TARGETS "${name}" ARCHIVE DESTINATION lib/)
	endif(doinstall)

endfunction(create_static_library)

function(create_pic_library name output_name src doinstall)

	# Add the library and link its dependencies.
	add_library("${name}" STATIC "${src}")
	target_link_libraries("${name}" "${ARGN}")

	# Set its output name.
	set_target_properties("${name}"
		PROPERTIES
		OUTPUT_NAME "${output_name}"
		POSITION_INDEPENDENT_CODE ON)

	# Install it, if necessary.
	if(doinstall)
		install(TARGETS "${name}" ARCHIVE DESTINATION lib/)
	endif(doinstall)

endfunction(create_pic_library)

function(create_merge_library name src)

	# Create a pic library.
	create_pic_library("${name}" "${name}" "${src}" NO "${ARGN}")

	# Put the lib in the list to merge.
	merge_lib("${name}" "${name}")

endfunction(create_merge_library)

function(create_all_libraries shared_name static_name pic_name output_name src doinstall)

	# Create libraries of all three types.
	create_shared_library("${shared_name}" "${output_name}" "${src}" "${doinstall}" "${ARGN}")
	create_static_library("${static_name}" "${output_name}" "${src}" "${doinstall}" "${ARGN}")
	create_pic_library("${pic_name}" "${output_name}_pic" "${src}" "${doinstall}" "${ARGN}")

endfunction(create_all_libraries)

