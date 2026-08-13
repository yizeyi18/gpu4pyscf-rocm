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

set(gdft_gpu_sources_base
  nr_eval_gto
  contract_rho
  gen_grids
  nr_numint_sparse
  vv10
  libxc
)

set(gdft_gpu_sources "")
foreach(src ${gdft_gpu_sources_base})
  list(APPEND gdft_gpu_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${gdft_gpu_sources} PROPERTIES LANGUAGE HIP)
endif()

add_library(gdft SHARED ${gdft_gpu_sources})

set_target_properties(gdft PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET gdft PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET gdft PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(gdft PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(gdft PRIVATE -fgpu-rdc)
endif()

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(gdft PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(gdft INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
