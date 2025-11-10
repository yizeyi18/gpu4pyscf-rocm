if(GPU4PYSCF_USE_CUDA)
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --ptxas-options=-v")
endif()

set(mgrid_gpu_sources_base
  mg_driver
  estimator
  eval_rho
  eval_mat_lda
  eval_mat_gga
  eval_tau
  eval_mat_tau
)

set(mgrid_gpu_sources "")
foreach(src ${mgrid_gpu_sources_base})
  list(APPEND mgrid_gpu_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${mgrid_gpu_sources} PROPERTIES LANGUAGE HIP)
endif()

add_library(mgrid SHARED ${mgrid_gpu_sources})

set_target_properties(mgrid PROPERTIES
  LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET mgrid PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET mgrid PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(mgrid PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(mgrid PRIVATE -fgpu-rdc)
endif()

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(mgrid PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(mgrid INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()

set(mgrid_v2_sources_base
  multigrid_v2/drivers
  multigrid_v2/screen
  multigrid_v2/eval_xc
  multigrid_v2/eval_xc_grad
)

set(mgrid_v2_sources "")
foreach(src ${mgrid_v2_sources_base})
  list(APPEND mgrid_v2_sources "${src}.${GPU4PYSCF_GPU_SOURCE_EXTENSION}")
endforeach()

if(GPU4PYSCF_USE_HIP)
  set_source_files_properties(${mgrid_v2_sources} PROPERTIES LANGUAGE HIP)
endif()

add_library(mgrid_v2 SHARED ${mgrid_v2_sources})

set_target_properties(mgrid_v2 PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}
)

if(GPU4PYSCF_USE_CUDA)
  set_property(TARGET mgrid_v2 PROPERTY CUDA_SEPARABLE_COMPILATION ON)
endif()
if(GPU4PYSCF_USE_HIP)
  set_property(TARGET mgrid_v2 PROPERTY HIP_SEPARABLE_COMPILATION ON)
  target_compile_options(mgrid_v2 PRIVATE $<$<COMPILE_LANGUAGE:HIP>:-fgpu-rdc>)
  target_link_options(mgrid_v2 PRIVATE -fgpu-rdc)
endif()

if(GPU4PYSCF_DEVICE_LIB)
  target_link_libraries(mgrid_v2 PRIVATE ${GPU4PYSCF_DEVICE_LIB})
endif()
if(GPU4PYSCF_HOST_LIB)
  target_link_libraries(mgrid_v2 INTERFACE ${GPU4PYSCF_HOST_LIB})
endif()
