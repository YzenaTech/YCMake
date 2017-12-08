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
#	The function merge_static_libs is under the following copyright and license:
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
set(SCRIPT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE STRING "Directory of the merge script")
set(MERGE_LIBS "" CACHE STRING "List of libraries to merge")

# For some reason, we get stupid CMake warnings.
cmake_policy(SET CMP0026 NEW)

function(static_lib_path var lib_output_name)

	# Build the path.
	string(CONCAT LIB_PATH
		"${CMAKE_CURRENT_BINARY_DIR}/"
		"${CMAKE_STATIC_LIBRARY_PREFIX}"
		"${lib_output_name}"
		"${CMAKE_STATIC_LIBRARY_SUFFIX}")

	# Set the variable in parent scope.
	set("${var} "${LIB_PATH}" PARENT_SCOPE)

endfunction(static_lib_path)

# Merge_static_libs(outlib lib1 lib2 ... libn) merges a number of static
# libs into a single static library
function(merge_static_libs outlib)

	set(libs ${ARGV})
	list(REMOVE_AT libs 0)

	# Create a dummy file that the target will depend on
	set(dummyfile ${CMAKE_CURRENT_BINARY_DIR}/${outlib}_dummy.c)
	file(WRITE ${dummyfile} "// ${dummyfile}")

	add_library(${outlib} STATIC ${dummyfile})
	static_lib_path(outfile "${outlib}")

	# Make sure all libs are static.
	foreach(lib ${MERGE_LIBS})
		get_target_property(libtype ${lib} TYPE)
		if(NOT libtype STREQUAL "STATIC_LIBRARY")
			message(FATAL_ERROR "Merge_static_libs can only process static libraries")
		endif()
	endforeach()

	# If we are on a multiconfig build system...
	if(NOT"${CMAKE_CFG_INTDIR}" STREQUAL ".")

		# Generate a list for each config type.
		foreach(lib ${MERGE_LIBS})
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

	# Rename.
	set(libfiles "${MERGE_LIBS}")

	# Just to be sure: cleanup from duplicates
	list(REMOVE_DUPLICATES libfiles)

	message(STATUS "will be merging ${libfiles}")

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

		get_target_property(outfile ${outlib} LOCATION)
		add_custom_command(TARGET ${outlib} POST_BUILD
			COMMAND rm ${outfile}
			COMMAND /usr/bin/libtool -static -o ${outfile} ${libfiles})

	else()

		# General UNIX - need to "ar -x" and then "ar -ru"

		# We can't handle multiconfigs.
		if(multiconfig)
			message(FATAL_ERROR "Multiple configurations are not supported")
		endif()

		# Loop over the files.
		foreach(lib ${libfiles})

			# objlistfile will contain the list of object files for the library.
			set(objlistfile ${lib}.objlist)
			set(objdir ${lib}.objdir)
			set(objlistcmake  ${objlistfile}.cmake)

			# we only need to extract files once
			if(${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/cmake.check_cache IS_NEWER_THAN ${objlistcmake})
				#---------------------------------
				string(CONCAT file_content
					"# Extract object files from the library
					message(STATUS \"Extracting object files from ${lib}\")
					execute_process(COMMAND ${CMAKE_AR} -x ${lib}
						WORKING_DIRECTORY ${objdir})
					# save the list of object files
					execute_process(COMMAND ls .
						OUTPUT_FILE ${objlistfile}
						WORKING_DIRECTORY ${objdir})")
				FILE(WRITE ${objlistcmake} "${file_content}")
				#---------------------------------
				file(MAKE_DIRECTORY ${objdir})
				add_custom_command(
					OUTPUT ${objlistfile}
					COMMAND ${CMAKE_COMMAND} -P ${objlistcmake}
					DEPENDS ${lib})
			endif()
			list(APPEND extrafiles "${objlistfile}")

			# relative path is needed by ar under MSYS
			file(RELATIVE_PATH objlistfilerpath ${objdir} ${objlistfile})
			add_custom_command(TARGET ${outlib} POST_BUILD
				COMMAND ${CMAKE_AR} ru "${outfile}" @"${objlistfilerpath}"
				WORKING_DIRECTORY ${objdir})
		endforeach()
		add_custom_command(TARGET ${outlib}
			POST_BUILD
			COMMAND ${CMAKE_RANLIB} ${outfile})
	endif()
	file(WRITE ${dummyfile}.base "const char* ${outlib}_sublibs=\"${libs}\";")
	add_custom_command(
		OUTPUT  ${dummyfile}
		COMMAND ${CMAKE_COMMAND}  -E copy ${dummyfile}.base ${dummyfile}
		DEPENDS ${libs} ${extrafiles})

endfunction()

function(merge_lib name output)

	static_lib_path(LIB_PATH "${output}")
	list(APPEND MERGE_LIBS "${LIB_PATH}")

endfunction(merge_lib)

function(create_test target)

	add_executable("${target}" "${target}.c")
	target_link_libraries("${target}" "${ARGN}")
	add_test(NAME ${target} COMMAND "$<TARGET_FILE:${target}>")

endfunction(create_test)

function(create_shared_library name output_name src doinstall)

	add_library("${name}" SHARED "${src}")
	target_link_libraries("${name}" "${ARGN}")

	set_target_properties("${name}"
		PROPERTIES
		OUTPUT_NAME "${output_name}")

	if(doinstall)
		install(TARGETS "${name}" LIBRARY DESTINATION lib/)
	endif(doinstall)

endfunction(create_shared_library)

function(create_static_library name output_name src doinstall domerge)

	add_library("${name}" STATIC "${src}")
	target_link_libraries("${name}" "${ARGN}")

	set_target_properties("${name}"
		PROPERTIES
		OUTPUT_NAME "${output_name}")

	if(doinstall)
		install(TARGETS "${name}" ARCHIVE DESTINATION lib/)
	endif(doinstall)

	if(domerge)
		merge_lib("${name}" "${output_name}")
	endif(domerge)

endfunction(create_static_library)

function(create_pic_library name output_name src doinstall)

	add_library("${name}" STATIC "${src}")
	target_link_libraries("${name}" "${ARGN}")

	set_target_properties("${name}"
		PROPERTIES
		OUTPUT_NAME "${output_name}"
		POSITION_INDEPENDENT_CODE ON)

	if(doinstall)
		install(TARGETS "${name}" ARCHIVE DESTINATION lib/)
	endif(doinstall)

	if(domerge)
		merge_lib("${name}" "${output_name}")
	endif(domerge)

endfunction(create_pic_library)

function(create_all_libraries shared_name static_name pic_name output_name src doinstall)

	create_shared_library("${shared_name}" "${output_name}" "${src}" "${doinstall}" "${ARGN}")
	create_static_library("${static_name}" "${output_name}" "${src}" "${doinstall}" NO "${ARGN}")
	create_pic_library("${pic_name}" "${output_name}_pic" "${src}" "${doinstall}" NO "${ARGN}")

endfunction(create_all_libraries)

