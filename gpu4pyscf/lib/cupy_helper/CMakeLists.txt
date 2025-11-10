# Copyright 2021-2024 The PySCF Developers. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_80")

set(cupy_helper_sources_base
  transpose
  block_diag
  unpack
  take_last2d
  async_d2h_2d
  add_sparse
  dist_matrix
  cart2sph
)

if(BUILD_CUTLASS)
  list(APPEND cupy_helper_sources_base grouped_gemm grouped_dot)
endif()

set(cupy_helper_sources "")
foreach(src ${cupy_helper_sources_base})
  list(APPEND cupy_helper_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${cupy_helper_sources} PROPERTIES LANGUAGE HIP)
endif()

add_library(cupy_helper SHARED ${cupy_helper_sources})

if(BUILD_CUTLASS)
    add_dependencies(cupy_helper cutlass)
    target_include_directories(cupy_helper PRIVATE ${cutlass_SOURCE_DIR}/tools/util/include ${cutlass_SOURCE_DIR}/include)
endif()

set_target_properties(cupy_helper PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR})
if(GPU4PYSCF_USE_HIP)
  set_target_properties(cupy_helper PROPERTIES HIP_ARCHITECTURES "${CMAKE_HIP_ARCHITECTURES}")
  set_property(TARGET cupy_helper PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(cupy_helper PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(cupy_helper PRIVATE -fgpu-rdc)
endif()
if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET cupy_helper PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(cupy_helper PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(cupy_helper INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
