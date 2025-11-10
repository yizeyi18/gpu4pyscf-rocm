if(GPU4PYSCF_USE_CUDA)
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --ptxas-options=-v")
endif()

set(gint_rys_sources_base
  gint_driver
  fill_int3c2e
  unrolled_int3c2e
  fill_int3c2e_bdiv
  unrolled_int3c2e_bdiv
  rys_roots_dat
)

set(gint_rys_sources "")
foreach(src ${gint_rys_sources_base})
  list(APPEND gint_rys_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${gint_rys_sources} PROPERTIES LANGUAGE HIP)
endif()

add_library(gint_rys SHARED ${gint_rys_sources})

set_target_properties(gint_rys PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET gint_rys PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET gint_rys PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(gint_rys PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(gint_rys PRIVATE -fgpu-rdc)
endif()

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(gint_rys PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(gint_rys INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
