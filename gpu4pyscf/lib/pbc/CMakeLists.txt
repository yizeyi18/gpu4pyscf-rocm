if(GPU4PYSCF_USE_CUDA)
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --ptxas-options=-v")
endif()

set(pbc_gpu_sources_base
  pbc_driver
  ft_ao
  unrolled_ft_ao
  ft_ao_bdiv
  ft_ao_ip1
  fill_int3c2e
  unrolled_int3c2e
  fill_int2c2e
  fill_int3c2e_v2
  overlap
  estimator
  rys_roots_dat
  rys_contract_k
  rys_contract_jk_ip1
  nr_eval_gto
)

set(pbc_gpu_sources "")
foreach(src ${pbc_gpu_sources_base})
  list(APPEND pbc_gpu_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${pbc_gpu_sources} PROPERTIES LANGUAGE HIP)
endif()

set(pbc_cpu_sources sorting.c)

add_library(pbc SHARED
  ${pbc_gpu_sources}
  ${pbc_cpu_sources}
)

set_target_properties(pbc PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET pbc PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET pbc PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(pbc PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(pbc PRIVATE -fgpu-rdc)
endif()

target_link_libraries(pbc PRIVATE OpenMP::OpenMP_C)

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(pbc PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(pbc INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
