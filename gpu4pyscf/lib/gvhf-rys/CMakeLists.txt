if(GPU4PYSCF_USE_CUDA)
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --ptxas-options=-v")
endif()

set(gvhf_rys_gpu_sources_base
  rys_contract_jk
  rys_jk_driver
  rys_roots_dat
  unrolled_os
  unrolled_rys
  rys_contract_j
  unrolled_rys_j
  count_tasks
  rys_contract_jk_ip1
  unrolled_rys_ip1
  unrolled_ejk_ip1
  rys_contract_jk_ip2
  unrolled_ejk_ip2_type12
  unrolled_ejk_ip2_type3
)

set(gvhf_rys_gpu_sources "")
foreach(src ${gvhf_rys_gpu_sources_base})
  list(APPEND gvhf_rys_gpu_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${gvhf_rys_gpu_sources} PROPERTIES LANGUAGE HIP)
endif()

set(gvhf_rys_cpu_sources
  nr_sr_estimator.c
  cart2xyz.c
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
