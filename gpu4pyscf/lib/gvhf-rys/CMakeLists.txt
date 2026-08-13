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

set(gvhf_rys_gpu_sources_base
  rys_jk_driver
  rys_roots_dat
  nr_sr_estimator
  rys_contract_j
  rys_constant
  rys_contract_k
  unrolled_rys_k
  rys_contract_jk
  unrolled_rys_jk
  rys_contract_jk_ip1
  unrolled_rys_jk_ip1
  unrolled_ejk_ip1
  rys_contract_jk_ip2
  unrolled_ejk_ip2_type12
  unrolled_ejk_ip2_type3
  contract_int3c2e
  mole_helper
  ejk_int3c2e_ip1
  fill_int3c2e
  int3c2e_recontract
  decompress
  ejk_int3c2e_ip2
  fill_int3c2e_ip1
  e_int2c2e_ip2
)

set(gvhf_rys_gpu_sources "")
foreach(src ${gvhf_rys_gpu_sources_base})
  list(APPEND gvhf_rys_gpu_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${gvhf_rys_gpu_sources} PROPERTIES LANGUAGE HIP)
  set_source_files_properties(unrolled_ejk_ip1.hip PROPERTIES COMPILE_OPTIONS "-O0;-g0")
  set_source_files_properties(unrolled_ejk_ip2_type12.hip PROPERTIES COMPILE_OPTIONS "-O0;-g0")
  set_source_files_properties(unrolled_ejk_ip2_type3.hip PROPERTIES COMPILE_OPTIONS "-O0;-g0")
endif()

set(gvhf_rys_cpu_sources
  nr_sr_estimator.c
  cart2xyz.c
  utils.c
)

add_library(gvhf_rys SHARED
  ${gvhf_rys_gpu_sources}
  ${gvhf_rys_cpu_sources}
)

set_target_properties(gvhf_rys PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET gvhf_rys PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET gvhf_rys PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(gvhf_rys PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(gvhf_rys PRIVATE -fgpu-rdc)
endif()

target_link_libraries(gvhf_rys PRIVATE OpenMP::OpenMP_C)
if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(gvhf_rys PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(gvhf_rys INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
