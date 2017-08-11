#	***** BEGIN LICENSE BLOCK *****
#
#	Copyright 2017 Project LFyre
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

function (create_library name src doinstall)

	# Do the shared library only on platforms other than Windows.
	if (NOT WIN32)
		set(SHARED_NAME "${name}_shared")
		add_library("${SHARED_NAME}" SHARED "${src}")
		set_target_properties("${SHARED_NAME}" PROPERTIES OUTPUT_NAME "${name}")
		target_link_libraries("${SHARED_NAME}" "${ARGN}")
		if (doinstall)
			install(TARGETS "${SHARED_NAME}" LIBRARY DESTINATION lib/)
		endif()
	endif()

	# Static library.
	set(STATIC_NAME "${name}_static")
	add_library("${STATIC_NAME}" STATIC "${src}")
	set_target_properties("${STATIC_NAME}" PROPERTIES OUTPUT_NAME "${name}")
	target_link_libraries("${STATIC_NAME}" "${ARGN}")
	if (doinstall)
		install(TARGETS "${STATIC_NAME}" ARCHIVE DESTINATION lib/)
	endif()

endfunction (create_library)
