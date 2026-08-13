/*
 * Copyright 2021-2025 The PySCF Developers. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <stdio.h>
#include "ecp.h"
#include "bessel.hip"
#include "cart2sph.hip"
#include "gauss_chebyshev.hip"
#include "common.hip"
#include "type1_ang_nuc.hip"
#include "type2_ang_nuc.hip"
#include "ecp_type1.hip"
#include "ecp_type2.hip"
#include "ecp_type1_ip.hip"
#include "ecp_type2_ip.hip"
#include "ecp_type1_ipip.hip"
#include "ecp_type2_ipip.hip"

// Kernel-exact sizes of the shared-memory and scratch buffers of the
// type2 ECP kernels. On HIP (gfx906, 64KB shared memory per block) the
// omegai/omegaj buffers are stored in a per-task global scratch region.
#define ECP_OMEGA_I_SIZE(LI, LC) (((LI)+(LC)+2)/2 * ((LI)+1)*((LI)+2)*((LI)+3)/6 * (2*(LC)+1))
#define ECP_OMEGA_J_SIZE(LJ, LC) (((LJ)+(LC)+2)/2 * ((LJ)+1)*((LJ)+2)*((LJ)+3)/6 * (2*(LC)+1))
#define ECP_RAD_ALL_SIZE(LI, LJ, LC) ((LI)+(LJ)+1) * ((LI)+(LC)+1) * ((LJ)+(LC)+1)
#define ECP_ANGI_SIZE(LI, LC) ((LI)+1) * ((LI)+1)*((LI)+2)/2 * ((LI)+(LC)+1)
#define ECP_ANGJ_SIZE(LJ, LC) ((LJ)+1) * ((LJ)+1)*((LJ)+2)/2 * ((LJ)+(LC)+1)

extern "C" {
int ECP_cart(double *gctr,
            const int *ao_loc, const int nao,
            const int *tasks, const int ntasks,
            const int *ecpbas, const int *ecploc,
            const int *atm, const int *bas, const double *env,
            const int li, const int lj, const int lc){
    // one task per thread block
    dim3 threads(THREADS);
    dim3 blocks(ntasks);
    if (lc >= 0){
        int task_type = li * 100 + lj * 10 + lc;
        switch (task_type) {
        case 0:  type2_cart<0,0,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 1:  type2_cart<0,0,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 2:  type2_cart<0,0,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 3:  type2_cart<0,0,3><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 10:  type2_cart<0,1,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 11:  type2_cart<0,1,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 12:  type2_cart<0,1,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 110: type2_cart<1,1,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 111: type2_cart<1,1,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 112: type2_cart<1,1,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 20:  type2_cart<0,2,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 21:  type2_cart<0,2,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 30:  type2_cart<0,3,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 120: type2_cart<1,2,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;

        // General kernel
        default: {
            const int li1 = li+1;
            const int lj1 = lj+1;
            const int nfi = (li+1)*(li+2)/2;
            const int nfj = (lj+1)*(lj+2)/2;
            const int lic1 = li+lc+1;
            const int ljc1 = lj+lc+1;
            const int lcc1 = 2*lc+1;
            const int blki = (lic1+1)/2 * lcc1;
            const int blkj = (ljc1+1)/2 * lcc1;

            int smem_size0 = (li+lj+1) * lic1 * ljc1; // rad_all
            int smem_size1 = li1*(li1+1)*(li1+2)/6 * blki; // omegai
            int smem_size2 = lj1*(lj1+1)*(lj1+2)/6 * blkj; // omegaj
            int smem_size3 = li1*nfi*lic1; // angi
            int smem_size4 = lj1*nfj*ljc1; // angj
            int smem_size = smem_size0 + smem_size1 + smem_size2 + smem_size3 + smem_size4;

            type2_cart<<<blocks, threads, smem_size*sizeof(double)>>>(
                gctr,
                li, lj, lc,
                ao_loc, nao,
                tasks, ntasks,
                ecpbas, ecploc,
                atm, bas, env);
        }}
    } else {
        int task_type = li * 10 + lj;
        switch (task_type)
        {
        case 0:  type1_cart<0,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 1:  type1_cart<0,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 11: type1_cart<1,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 2:  type1_cart<0,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 3:  type1_cart<0,3><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 12: type1_cart<1,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 4:  type1_cart<0,4><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 13: type1_cart<1,3><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 22: type1_cart<2,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        default: {
            const int lij1 = li+lj+1;
            const int lij3 = lij1*lij1*lij1;

            int smem_size = 0;
            smem_size += lij3;      // rad_ang
            smem_size += lij1*lij1; // rad_all
            type1_cart<<<blocks, threads, smem_size*sizeof(double)>>>(
                gctr, li, lj,
                ao_loc, nao,
                tasks, ntasks,
                ecpbas, ecploc,
                atm, bas, env);
        }
        }
    }
    hipError_t err = hipGetLastError();
    if (err != hipSuccess) {
        fprintf(stderr, "CUDA Error in %s (li,lj,lc = %d,%d,%d): %s\n", __func__, li,lj,lc, hipGetErrorString(err));
        return 1;
    }
    return 0;
    }

int ECP_ip_cart(double *gctr,
            const int *ao_loc, const int nao,
            const int *tasks, const int ntasks,
            const int *ecpbas, const int *ecploc,
            const int *atm, const int *bas, const double *env,
            const int li, const int lj, const int lc,
            double *scratch, const int omega_stride){
    // one task per thread block
    dim3 threads(THREADS);
    dim3 blocks(ntasks);
    if (lc < 0){
        int task_type = li * 10 + lj;
        switch (task_type) {
        case 0:  type1_cart_ip1<0,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 1:  type1_cart_ip1<0,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 11: type1_cart_ip1<1,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 2:  type1_cart_ip1<0,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 3:  type1_cart_ip1<0,3><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 12: type1_cart_ip1<1,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 4:  type1_cart_ip1<0,4><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 13: type1_cart_ip1<1,3><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 22: type1_cart_ip1<2,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        default: {
            const int lij1 = li+lj+2;
            const int lij3 = lij1*lij1*lij1;

            int smem_size = 0;
            smem_size += lij3;      // rad_ang
            smem_size += lij1*lij1; // rad_all
            type1_cart_ip1_general<<<blocks, threads, smem_size*sizeof(double)>>>(
                gctr, li, lj,
                ao_loc, nao,
                tasks, ntasks,
                ecpbas, ecploc,
                atm, bas, env);
        }}
    } else {
        int task_type = li * 100 + lj * 10 + lc;
        switch (task_type) {
        case 0:  type2_cart_ip1<0,0,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 1:  type2_cart_ip1<0,0,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 2:  type2_cart_ip1<0,0,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 3:  type2_cart_ip1<0,0,3><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 10:  type2_cart_ip1<0,1,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 11:  type2_cart_ip1<0,1,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 12:  type2_cart_ip1<0,1,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 110: type2_cart_ip1<1,1,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 111: type2_cart_ip1<1,1,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 112: type2_cart_ip1<1,1,2><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 20:  type2_cart_ip1<0,2,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 21:  type2_cart_ip1<0,2,1><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 30:  type2_cart_ip1<0,3,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;
        case 120: type2_cart_ip1<1,2,0><<<blocks, threads>>>(gctr, ao_loc, nao, tasks, ntasks, ecpbas, ecploc, atm, bas, env); break;

        // General kernel. The omegai/omegaj buffers of type2_cart_kernel
        // live in a per-task global scratch region (see ecp_type2_ip.hip), so
        // the dynamic shared memory only holds rad_all, angi and angj.
        default: {
            const int li1 = li+1; // LI of the type2_cart_kernel<1,0> call
            const int rad_all = ECP_RAD_ALL_SIZE(li1, lj, lc);
            const int angi = ECP_ANGI_SIZE(li1, lc);
            const int angj = ECP_ANGJ_SIZE(lj, lc);
            int dynamic_smem_size = rad_all + angi + angj;
            hipError_t err = hipFuncSetAttribute(reinterpret_cast<const void*>(
                type2_cart_ip1_general),
                hipFuncAttributeMaxDynamicSharedMemorySize,
                dynamic_smem_size*sizeof(double));

            if (err != hipSuccess) {
                fprintf(stderr, "CUDA Error in hipFuncSetAttribute %s (li,lj,lc = %d,%d,%d): %s\n", __func__, li,lj,lc, hipGetErrorString(err));
                return 1;
            }

            type2_cart_ip1_general<<<blocks, threads, dynamic_smem_size*sizeof(double)>>>(
                gctr, li, lj, lc,
                ao_loc, nao,
                tasks, ntasks,
                ecpbas, ecploc,
                atm, bas, env,
                scratch, omega_stride);
        }}
    }
    hipError_t err = hipGetLastError();
    if (err != hipSuccess) {
        fprintf(stderr, "CUDA Error in %s (li,lj,lc = %d,%d,%d): %s\n", __func__, li,lj,lc, hipGetErrorString(err));
        return 1;
    }
    return 0;
    }

int ECP_ipipv_cart(double *gctr,
            const int *ao_loc, const int nao,
            const int *tasks, const int ntasks,
            const int *ecpbas, const int *ecploc,
            const int *atm, const int *bas, const double *env,
            const int li, const int lj, const int lc,
            double *buf1_g, double *scratch, const int omega_stride){
    // one task per thread block
    dim3 threads(THREADS);
    dim3 blocks(ntasks);
    
    if (lc < 0){
        const int lij1 = li+lj+3; //
        const int lij3 = lij1*lij1*lij1;

        int smem_size = 0;
        smem_size += lij3;      // rad_ang
        smem_size += lij1*lij1; // rad_all
        type1_cart_ipipv<<<blocks, threads, smem_size*sizeof(double)>>>(
            gctr, li, lj,
            ao_loc, nao,
            tasks, ntasks,
            ecpbas, ecploc,
            atm, bas, env);

    } else {
        // The type2_cart_kernel<2,0> call (with LI = li+2) dominates both the
        // shared memory and the scratch requirements. omegai/omegaj live in
        // the per-task global scratch; buf1 also uses a per-task global buffer.
        const int li2 = li+2; // LI of the type2_cart_kernel<2,0> call
        const int rad_all = ECP_RAD_ALL_SIZE(li2, lj, lc);
        const int angi = ECP_ANGI_SIZE(li2, lc);
        const int angj = ECP_ANGJ_SIZE(lj, lc);
        int dynamic_smem_size = rad_all + angi + angj;

        hipError_t err = hipFuncSetAttribute(reinterpret_cast<const void*>(type2_cart_ipipv),
                                         hipFuncAttributeMaxDynamicSharedMemorySize,
                                         dynamic_smem_size*sizeof(double));
        if (err != hipSuccess) {
            fprintf(stderr, "CUDA Error in hipFuncSetAttribute %s (li,lj,lc = %d,%d,%d): %s\n", __func__, li,lj,lc, hipGetErrorString(err));
            return 1;
        }

        type2_cart_ipipv<<<blocks, threads, dynamic_smem_size*sizeof(double)>>>(
            gctr, li, lj, lc,
            ao_loc, nao,
            tasks, ntasks,
            ecpbas, ecploc,
            atm, bas, env,
            buf1_g, scratch, omega_stride);

    }
    hipError_t err = hipGetLastError();
    if (err != hipSuccess) {
        fprintf(stderr, "CUDA Error in %s (li,lj,lc = %d,%d,%d): %s\n", __func__, li,lj,lc, hipGetErrorString(err));
        return 1;
    }
    return 0;
    }

int ECP_ipvip_cart(double *gctr,
            const int *ao_loc, const int nao,
            const int *tasks, const int ntasks,
            const int *ecpbas, const int *ecploc,
            const int *atm, const int *bas, const double *env,
            const int li, const int lj, const int lc,
            double *buf1_g, double *scratch, const int omega_stride){
    // one task per thread block
    dim3 threads(THREADS);
    dim3 blocks(ntasks);

    if (lc < 0){
        const int lij1 = li+lj+3; //
        const int lij3 = lij1*lij1*lij1;

        int smem_size = 0;
        smem_size += lij3;      // rad_ang
        smem_size += lij1*lij1; // rad_all
        type1_cart_ipvip<<<blocks, threads, smem_size*sizeof(double)>>>(
            gctr, li, lj,
            ao_loc, nao,
            tasks, ntasks,
            ecpbas, ecploc,
            atm, bas, env);
    } else {
        // The type2_cart_kernel<1,1> call (LI = li+1, LJ = lj+1) dominates the
        // shared memory and the scratch requirements.
        const int li1 = li+1; // LI of the type2_cart_kernel<1,1> call
        const int lj1 = lj+1;
        const int rad_all = ECP_RAD_ALL_SIZE(li1, lj1, lc);
        const int angi = ECP_ANGI_SIZE(li1, lc);
        const int angj = ECP_ANGJ_SIZE(lj1, lc);
        int dynamic_smem_size = rad_all + angi + angj;

        hipError_t err = hipFuncSetAttribute(reinterpret_cast<const void*>(
            type2_cart_ipvip),
            hipFuncAttributeMaxDynamicSharedMemorySize,
            dynamic_smem_size*sizeof(double));
        if (err != hipSuccess) {
            fprintf(stderr, "CUDA Error in hipFuncSetAttribute %s (li,lj,lc = %d,%d,%d): %s\n", __func__, li,lj,lc, hipGetErrorString(err));
            return 1;
        }

        type2_cart_ipvip<<<blocks, threads, dynamic_smem_size*sizeof(double)>>>(
            gctr, li, lj, lc,
            ao_loc, nao,
            tasks, ntasks,
            ecpbas, ecploc,
            atm, bas, env,
            buf1_g, scratch, omega_stride);
    }
    hipError_t err = hipGetLastError();
    if (err != hipSuccess) {
        fprintf(stderr, "CUDA Error in %s (li,lj,lc = %d,%d,%d): %s\n", __func__, li,lj,lc, hipGetErrorString(err));
        return 1;
    }
    return 0;
    }
}
