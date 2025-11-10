if(GPU4PYSCF_USE_CUDA)
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --ptxas-options=-v")
endif()

set(gvhf_md_gpu_sources_base
  md_contract_j
  unrolled_md_j
  unrolled_md_j_4dm
  md_indices
  md_j_driver
)

set(gvhf_md_gpu_sources "")
foreach(src ${gvhf_md_gpu_sources_base})
  list(APPEND gvhf_md_gpu_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${gvhf_md_gpu_sources} PROPERTIES LANGUAGE HIP)
endif()

set(gvhf_md_cpu_sources md_pairdata.c)

add_library(gvhf_md SHARED
  ${gvhf_md_gpu_sources}
  ${gvhf_md_cpu_sources}
)

set_target_properties(gvhf_md PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET gvhf_md PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET gvhf_md PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(gvhf_md PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(gvhf_md PRIVATE -fgpu-rdc)
endif()

target_link_libraries(gvhf_md PRIVATE OpenMP::OpenMP_C)

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(gvhf_md PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(gvhf_md INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
