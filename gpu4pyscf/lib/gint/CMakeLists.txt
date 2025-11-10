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

if(GPU4PYSCF_USE_CUDA)
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --ptxas-options=-v")
endif()

set(CMAKE_VERBOSE_MAKEFILE ON)
set(gint_gpu_sources_base
  bpcache
  constant
  nr_fill_ao_ints
  nr_fill_ao_int3c1e
  nr_fill_ao_int3c1e_ip
  nr_fill_ao_int3c1e_ipip
  nr_fill_ao_int3c2e
  nr_fill_ao_int3c2e_ip1
  nr_fill_ao_int3c2e_ip2
  nr_fill_ao_int3c2e_ipip1
  nr_fill_ao_int3c2e_ipip2
  nr_fill_ao_int3c2e_ip1ip2
  nr_fill_ao_int3c2e_ipvip1
  rys_roots_dat
  cart2sph
)

set(gint_gpu_sources "")
foreach(src ${gint_gpu_sources_base})
  list(APPEND gint_gpu_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${gint_gpu_sources} PROPERTIES LANGUAGE HIP)
endif()

set(gint_cpu_sources
  g2e.c
  pair_data.c
  j_engine_matrix_reorder.c
)

add_library(gint SHARED
  ${gint_cpu_sources}
  ${gint_gpu_sources}
)

set_target_properties(gint PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET gint PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET gint PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(gint PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(gint PRIVATE -fgpu-rdc)
endif()

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(gint PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(gint INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
