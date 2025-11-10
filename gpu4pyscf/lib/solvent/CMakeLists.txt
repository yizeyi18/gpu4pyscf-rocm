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

#set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_30 -rdc=true")
#set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_80")
#set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_60 --ptxas-options=-v")
#set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -arch=sm_50 --ptxas-options=-v -maxrregcount=255")

set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -std=legacy -fPIC")
set(CMAKE_VERBOSE_MAKEFILE ON)
add_library(solvent SHARED
mnsol_interface.f90
mnsol_mem.F
mnsol.F
pcm.${GPU4PYSCF_GPU_SOURCE_EXTENSION}
)

set_target_properties(solvent PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR})

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(pcm.${GPU4PYSCF_GPU_SOURCE_EXTENSION} PROPERTIES LANGUAGE HIP)
  set_target_properties(solvent PROPERTIES HIP_ARCHITECTURES "${CMAKE_HIP_ARCHITECTURES}")
  target_compile_options(solvent PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(solvent PRIVATE -fgpu-rdc)
elseif(GPU4PYSCF_USE_CUDA)
  set_property(TARGET solvent PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(solvent PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(solvent INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
