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


import numpy as np
import cupy
import ctypes
from ctypes.util import find_library
from cupy_backends.cuda.libs import cusolver
from cupy_backends.cuda.libs import cublas
from cupy.cuda import device

librocsolver = find_library('rocsolver')
if librocsolver is None:
    raise ValueError("rocsolver.so not found")
librocsolver = ctypes.CDLL(librocsolver)
#librocblas   = find_library('rocblas')
#librocblas   = ctypes.CDLL(librocblas)

ROCSOLVER_EIG_TYPE_1 = 221
ROCSOLVER_EIG_TYPE_2 = 222
ROCSOLVER_EIG_TYPE_3 = 223

ROCSOLVER_EIG_MODE_NOVECTOR = 213
ROCSOLVER_EIG_MODE_VECTOR = 211

rocblas_fill_upper = 121
rocblas_fill_lower = 122
rocblas_fill_full  = 123

#librocsolver.cusolverDnDsygvd_bufferSize.restype = int
librocsolver.rocsolver_dsygvd.restype = int

_buffersize = {}

# https://docs.nvidia.com/cuda/cusolver/index.html#cusolverdn-t-sygvd
#librocsolver.cusolverDnDsygvd_bufferSize.argtypes = [
#    ctypes.c_void_p, # handle
#    ctypes.c_int,    # itype
#    ctypes.c_int,    # jobz
#    ctypes.c_int,    # uplo
#    ctypes.c_int,    # n
#    ctypes.c_void_p, # *A
#    ctypes.c_int,    # lda
#    ctypes.c_void_p, # *B
#    ctypes.c_int,    # ldb
#    ctypes.c_void_p, # *w
#    ctypes.c_void_p  # *lwork
#]

librocsolver.rocsolver_dsygvd.argtypes = [
    ctypes.c_void_p,  # handle
    ctypes.c_int,     # itype
    ctypes.c_int,     # evect
    ctypes.c_int,     # uplo
    ctypes.c_int,     # n
    ctypes.c_void_p,  # *A
    ctypes.c_int,     # lda
    ctypes.c_void_p,  # *B
    ctypes.c_int,     # ldb
    ctypes.c_void_p,  # *D
    ctypes.c_void_p,  # *E
    ctypes.c_void_p   # *Info
]

# https://docs.nvidia.com/cuda/cusolver/index.html#cusolverdn-t-sygvd
#librocsolver.cusolverDnZhegvd_bufferSize.argtypes = [
#    ctypes.c_void_p, # handle
#    ctypes.c_int,    # itype
#    ctypes.c_int,    # jobz
#    ctypes.c_int,    # uplo
#    ctypes.c_int,    # n
#    ctypes.c_void_p, # *A
#    ctypes.c_int,    # lda
#    ctypes.c_void_p, # *B
#    ctypes.c_int,    # ldb
#    ctypes.c_void_p, # *w
#    ctypes.c_void_p  # *lwork
#]

librocsolver.rocsolver_zhegvd.argtypes = [
    ctypes.c_void_p,  # handle
    ctypes.c_int,     # itype
    ctypes.c_int,     # evect
    ctypes.c_int,     # uplo
    ctypes.c_int,     # n
    ctypes.c_void_p,  # *A
    ctypes.c_int,     # lda
    ctypes.c_void_p,  # *B
    ctypes.c_int,     # ldb
    ctypes.c_void_p,  # *D
    ctypes.c_void_p,  # *E
    ctypes.c_void_p   # *Info
]

librocsolver.rocblas_set_workspace.argtypes = [
    ctypes.c_void_p,  # handle
    ctypes.c_void_p,  # addr
    ctypes.c_size_t   # size
]

def eigh(h, s, overwrite=False):
    '''
    solve generalized eigenvalue problem
    '''
    assert h.dtype == s.dtype
    assert h.dtype in (np.float64, np.complex128)
    n = h.shape[0]
    if h.dtype == np.complex128 and h.flags.c_contiguous:
        # zhegvd requires the matrices in F-order. For hermitian matrices,
        # .T.copy() is equivalent to .conj()
        A = h.conj()
        B = s.conj()
    elif overwrite:
        A = h
        B = s
    else:
        A = h.copy()
        B = s.copy()
    _handle = device.get_cusolver_handle()
    w = cupy.zeros(n)

    # TODO: reuse workspace
    if (h.dtype, n) in _buffersize:
        lwork = _buffersize[h.dtype, n]
    else:
        lwork = ctypes.c_int(0)
        _buffersize[h.dtype, n] = lwork
        status = 0

        if status != 0:
            raise RuntimeError(f"failed in buffer size ({status})")

    if h.dtype == np.float64:
        fn = librocsolver.rocsolver_dsygvd
    else:
        fn = librocsolver.rocsolver_zhegvd
    #work = cupy.empty(lwork, dtype=h.dtype)
    E = cupy.empty(n, dtype=h.dtype)
    devInfo = cupy.empty(1, dtype=np.int32)
    #status = librocsolver.rocblas_set_workspace(_handle, work.data.ptr, lwork)
    status = fn(
        _handle,
        ROCSOLVER_EIG_TYPE_1,
        ROCSOLVER_EIG_MODE_VECTOR,
        rocblas_fill_upper,
        n,
        A.data.ptr,
        n,
        B.data.ptr,
        n,
        w.data.ptr,
        E.data.ptr,
        devInfo.data.ptr,
    )

    if status != 0:
        raise RuntimeError("failed in eigh kernel")
    return w, A.T

def cholesky(A):
    n = len(A)
    assert A.flags['C_CONTIGUOUS']
    x = A.copy()
    handle = device.get_cusolver_handle()
    if A.dtype == np.float64:
        potrf = cusolver.dpotrf
        potrf_bufferSize = cusolver.dpotrf_bufferSize
    else:
        potrf = cusolver.zpotrf
        potrf_bufferSize = cusolver.zpotrf_bufferSize
    buffersize = potrf_bufferSize(handle, cublas.CUBLAS_FILL_MODE_UPPER, n, x.data.ptr, n)
    workspace = cupy.empty(buffersize, dtype=A.dtype)
    dev_info = cupy.empty(1, dtype=np.int32)
    potrf(handle, cublas.CUBLAS_FILL_MODE_UPPER, n, x.data.ptr, n,
        workspace.data.ptr, buffersize, dev_info.data.ptr)

    if dev_info[0] != 0:
        raise RuntimeError('failed to perform Cholesky Decomposition')
    cupy.linalg._util._tril(x,k=0)
    return x
