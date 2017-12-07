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

# For some reason, we get stupid CMake warnings.
cmake_policy(SET CMP0026 NEW)

# Merge_static_libs(outlib lib1 lib2 ... libn) merges a number of static
# libs into a single static library
function(merge_static_libs outlib )

	set(libs ${ARGV})
	list(REMOVE_AT libs 0)

	# Create a dummy file that the target will depend on
	set(dummyfile ${CMAKE_CURRENT_BINARY_DIR}/${outlib}_dummy.c)
	file(WRITE ${dummyfile} "// ${dummyfile}")

	add_library(${outlib} STATIC ${dummyfile})

	if("${CMAKE_CFG_INTDIR}" STREQUAL ".")
		set(multiconfig FALSE)
	else()
		set(multiconfig TRUE)
	endif()

	# First get the file names of the libraries to be merged
	foreach(lib ${libs})
		get_target_property(libtype ${lib} TYPE)
		if(NOT libtype STREQUAL "STATIC_LIBRARY")
			message(FATAL_ERROR "Merge_static_libs can only process static libraries")
		endif()
		if(multiconfig)
			foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
				get_target_property("libfile_${CONFIG_TYPE}" ${lib} "LOCATION_${CONFIG_TYPE}")
				list(APPEND libfiles_${CONFIG_TYPE} ${libfile_${CONFIG_TYPE}})
			endforeach()
		else()
			set(libfile "$<TARGET_FILE:${lib}>")
			list(APPEND libfiles "${libfile}")
		endif(multiconfig)
	endforeach()
	message(STATUS "Will be merging ${libfiles}")

	# Just to be sure: cleanup from duplicates
	if(multiconfig)
		foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
			list(REMOVE_DUPLICATES libfiles_${CONFIG_TYPE})
			set(libfiles ${libfiles} ${libfiles_${CONFIG_TYPE}})
		endforeach()
	endif()
	list(REMOVE_DUPLICATES libfiles)

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
		# Use OSX's libtool to merge archives
		if(multiconfig)
			message(FATAL_ERROR "Multiple configurations are not supported")
		endif()
		set(outfile "$<TARGET_FILE:${outlib}>")
		add_custom_command(TARGET ${outlib} POST_BUILD
			COMMAND rm ${outfile}
			COMMAND /usr/bin/libtool -static -o ${outfile}
			${libfiles})
	else()
		# general UNIX - need to "ar -x" and then "ar -ru"
		if(multiconfig)
			message(FATAL_ERROR "Multiple configurations are not supported")
		endif()
		set(outfile "$<TARGET_FILE:${outlib}>")
		message(STATUS "Outfile location is ${outfile}")
		foreach(lib ${libfiles})
			# objlistfile will contain the list of object files for the library
			set(objlistfile ${lib}.objlist)
			set(objdir ${lib}.objdir)
			set(objlistcmake  ${objlistfile}.cmake)
			# we only need to extract files once
			if(${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/cmake.check_cache IS_NEWER_THAN ${objlistcmake})
				#---------------------------------
				configure_file("${SCRIPT_DIR}/merge.cmake.in" "${CMAKE_CURRENT_BINARY_DIR}/merge_${objlistfile}.cmake" @ONLY)
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
				COMMAND ${CMAKE_COMMAND} -E echo "Running: ${CMAKE_AR} ru ${outfile} @${objlistfilerpath}"
				COMMAND ${CMAKE_AR} ru "${outfile}" @"${objlistfilerpath}"
				WORKING_DIRECTORY ${objdir})
		endforeach()
		add_custom_command(TARGET ${outlib}
			POST_BUILD
			COMMAND ${CMAKE_COMMAND} -E echo "Running: ${CMAKE_RANLIB} ${outfile}"
			COMMAND ${CMAKE_RANLIB} ${outfile})
	endif()
	file(WRITE ${dummyfile}.base "const char* ${outlib}_sublibs=\"${libs}\";")
	add_custom_command(
		OUTPUT  ${dummyfile}
		COMMAND ${CMAKE_COMMAND}  -E copy ${dummyfile}.base ${dummyfile}
		DEPENDS ${libs} ${extrafiles})

 endfunction()


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

function(create_static_library name output_name src doinstall)

	add_library("${name}" STATIC "${src}")
	target_link_libraries("${name}" "${ARGN}")

	set_target_properties("${name}"
		PROPERTIES
		OUTPUT_NAME "${output_name}")

	if(doinstall)
		install(TARGETS "${name}" ARCHIVE DESTINATION lib/)
	endif(doinstall)

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

endfunction(create_pic_library)

function(create_all_libraries shared_name static_name pic_name output_name src doinstall)

	create_shared_library("${shared_name}" "${output_name}" "${src}" "${doinstall}" "${ARGN}")
	create_static_library("${static_name}" "${output_name}" "${src}" "${doinstall}" "${ARGN}")
	create_pic_library("${pic_name}" "${output_name}_pic" "${src}" "${doinstall}" "${ARGN}")

endfunction(create_all_libraries)

