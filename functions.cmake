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
#	****** END LICENSE BLOCK ******

function (create_test target)

	add_executable("${target}" "${target}.c")
	target_link_libraries("${target}" "${ARGN}")
	add_test (NAME ${target} COMMAND $<TARGET_FILE:${target}>)

endfunction (create_test)

function (create_shared_library name output_name src doinstall)

	add_library("${name}" SHARED "${src}")
	target_link_libraries("${name}" "${ARGN}")

	set_target_properties("${name}" PROPERTIES OUTPUT_NAME "${output_name}")

	if (doinstall)
		install(TARGETS "${name}" LIBRARY DESTINATION lib/)
	endif(doinstall)

endfunction (create_shared_library)

function (create_static_library name output_name src doinstall)

	add_library("${name}" STATIC "${src}")
	target_link_libraries("${name}" "${ARGN}")

	set_target_properties("${name}" PROPERTIES OUTPUT_NAME "${output_name}")

	if (doinstall)
		install(TARGETS "${name}" ARCHIVE DESTINATION lib/)
	endif(doinstall)

endfunction (create_static_library)

function (create_pic_library name output_name src doinstall)

	add_library("${name}" STATIC "${src}")
	target_link_libraries("${name}" "${ARGN}")

	set_target_properties("${name}" PROPERTIES OUTPUT_NAME "${output_name}")
	set_property(TARGET "${name}" PROPERTY POSITION_INDEPENDENT_CODE ON)

	if (doinstall)
		install(TARGETS "${name}" ARCHIVE DESTINATION lib/)
	endif(doinstall)

endfunction (create_pic_library)

function (create_all_libraries shared_name static_name pic_name output_name src doinstall)

	create_shared_library("${shared_name}" "${output_name}" "${src}" "${doinstall}" "${ARGN}")
	create_static_library("${static_name}" "${output_name}" "${src}" "${doinstall}" "${ARGN}")
	create_pic_library("${pic_name}" "${output_name}_pic" "${src}" "${doinstall}" "${ARGN}")

endfunction (create_all_libraries)
