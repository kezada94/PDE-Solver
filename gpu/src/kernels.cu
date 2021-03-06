#include "kernels.cuh"
#include "defines.h"
#include <cuda.h>


#include "EquationAlfa.cuh"
#include "EquationF.cuh"
#include "EquationG.cuh"



__global__ void fillInitialCondition(REAL* a, REAL* F, REAL *G, size_t l, size_t M, size_t N, size_t O, size_t phi_offset, size_t globalWidth, REAL dt, REAL dr, REAL dtheta, REAL dphi, REAL l_1, REAL l_2, REAL bigl, int p, int q, int L, REAL* a_0){

	int r = blockIdx.x*blockDim.x + threadIdx.x;
	int theta = blockIdx.y*blockDim.y + threadIdx.y;
	int phi = blockIdx.z*blockDim.z + threadIdx.z;


	if (r<M && theta<N && phi<O){
		int global_phi = phi + phi_offset;

		a[I(l, phi, theta, r)] = a_0[r] + PI_1;
		F[I(l, phi, theta, r)] = q*(dtheta*theta) + PI_2;
		G[I(l, phi, theta, r)] = p*((dt*(REAL)l)/(REAL)L - dphi*(REAL)global_phi) + PI_3;
	}
} 



void computeNextIteration(REAL* a, REAL* F, REAL *G, size_t l, size_t tp1, size_t t, size_t tm1, size_t tm2, size_t M, size_t N, size_t O, size_t phi_offset, size_t globalWidth, REAL dt, REAL dr, REAL dtheta, REAL dphi, REAL l_1, REAL l_2, REAL lamb, int p, int q, int L, REAL* a_0, dim3 b, dim3 g, size_t sharedMemorySizeb){

    computeNexta<<<g, b, sharedMemorySizeb>>>(a, F, G, l, tp1, t, tm1, tm2, M, N, O, phi_offset, dt, dr, dtheta, dphi, l_1, l_2, lamb, p, q, L);
    cucheck(cudaDeviceSynchronize());

    computeNextF<<<g, b, sharedMemorySizeb>>>(a, F, G, l, tp1, t, tm1, tm2, M, N, O, phi_offset, dt, dr, dtheta, dphi, l_1, l_2, lamb, p, q, L);
    cucheck(cudaDeviceSynchronize());

    computeNextG<<<g, b, sharedMemorySizeb>>>(a, F, G, l, tp1, t, tm1, tm2, M, N, O, phi_offset, dt, dr, dtheta, dphi, l_1, l_2, lamb, p, q, L);
    cucheck(cudaDeviceSynchronize());
}

void computeFirstIteration(REAL* a, REAL* F, REAL *G, size_t l, size_t tp1, size_t t, size_t tm1, size_t tm2, size_t M, size_t N, size_t O, size_t phi_offset, size_t globalWidth, REAL dt, REAL dr, REAL dtheta, REAL dphi, REAL l_1, REAL l_2, REAL lamb, int p, int q, int L, REAL* a_0, dim3 b, dim3 g, size_t sharedMemorySizeb){

	computeFirsta<<<g, b, sharedMemorySizeb>>>(a, F, G, l, tp1, t, tm1, tm2, M, N, O, phi_offset, dt, dr, dtheta, dphi, l_1, l_2, lamb, p, q, L);
    cucheck(cudaDeviceSynchronize());

	computeFirstF<<<g, b, sharedMemorySizeb>>>(a, F, G, l, tp1, t, tm1, tm2, M, N, O, phi_offset, dt, dr, dtheta, dphi, l_1, l_2, lamb, p, q, L);
    cucheck(cudaDeviceSynchronize());

	computeFirstG<<<g, b, sharedMemorySizeb>>>(a, F, G, l, tp1, t, tm1, tm2, M, N, O, phi_offset, dt, dr, dtheta, dphi, l_1, l_2, lamb, p, q, L);
    cucheck(cudaDeviceSynchronize());
}

__global__ void fillTemporalGhostVolume(REAL* a, REAL* F, REAL *G, size_t M, size_t N, size_t O, size_t phi_offset, size_t globalWidth, REAL dt, REAL p){
	int r = blockIdx.x*blockDim.x + threadIdx.x;
	int theta = blockIdx.y*blockDim.y + threadIdx.y;
	int phi = blockIdx.z*blockDim.z + threadIdx.z;

	if (r<M && theta<N && phi<O){
	    int global_phi = phi + phi_offset;
		
		a[I(0, phi, theta, r)] = a[I(2, phi, theta, r)];
		F[I(0, phi, theta, r)] = F[I(2, phi, theta, r)];
		G[I(0, phi, theta, r)] = G[I(2, phi, theta, r)] - 2*dt*p;
		
	}
}

__global__ void fillGhostPoints(REAL* a, REAL* F, REAL *G, size_t t, size_t M, size_t N, size_t O, size_t phi_offset, size_t globalWidth){
	int r = blockIdx.x*blockDim.x + threadIdx.x;
	int theta = blockIdx.y*blockDim.y + threadIdx.y;
	int phi = blockIdx.z*blockDim.z + threadIdx.z;
	for(size_t n=0; n<N+2; n++){
		for(size_t o=0; o<O+2; o++){
			a[E(t, 0, n, o)] = a[E(t, 2, n, o)];
			F[E(t, 0, n, o)] = F[E(t, 2, n, o)];
			G[E(t, 0, n, o)] = G[E(t, 2, n, o)];
		}
	}
	for(size_t m=0; m<M+2; m++){
		for(size_t o=0; o<O+2; o++){
			a[E(t, m, 0, o)] = a[E(t, m, 2, o)];
			F[E(t, m, 0, o)] = F[E(t, m, 2, o)];
			G[E(t, m, 0, o)] = G[E(t, m, 2, o)];
		}
	}	
	for(size_t m=0; m<M+2; m++){
		for(size_t n=0; n<N+2; n++){
			a[E(t, m, n, 0)] = a[E(t, m, n, 2)];
			F[E(t, m, n, 0)] = F[E(t, m, n, 2)];
			G[E(t, m, n, 0)] = G[E(t, m, n, 2)];
		}
	}

	// Boundary m=L
	for(size_t n=0; n<N+2; n++){
		for(size_t o=0; o<O+2; o++){
			a[E(t, M+1, n, o)] = a[E(t, M-1, n, o)];
			F[E(t, M+1, n, o)] = F[E(t, M-1, n, o)];
			G[E(t, M+1, n, o)] = G[E(t, M-1, n, o)];
		}
	}
	for(size_t m=0; m<M+2; m++){
		for(size_t o=0; o<O+2; o++){
			a[E(t, m, N+1, o)] = a[E(t, m, N-1, o)];
			F[E(t, m, N+1, o)] = F[E(t, m, N-1, o)];
			G[E(t, m, N+1, o)] = G[E(t, m, N-1, o)];
		}
	}	
	for(size_t m=0; m<M+2; m++){
		for(size_t n=0; n<N+2; n++){
			a[E(t, m, n, O+1)] = a[E(t, m, n, O-1)];
			F[E(t, m, n, O+1)] = F[E(t, m, n, O-1)];
			G[E(t, m, n, O+1)] = G[E(t, m, n, O-1)];
		}
	}
}

__global__ void fillDirichletBoundary(REAL* a, REAL* F, REAL *G, size_t l, size_t t, size_t M, size_t N, size_t O, size_t phi_offset, size_t globalWidth, REAL dt, REAL dr, REAL dtheta, REAL dphi, REAL l_1, REAL l_2, REAL lamb, int p, int q, int L, REAL* a_0){

	int r = blockIdx.x*blockDim.x + threadIdx.x;
	int theta = blockIdx.y*blockDim.y + threadIdx.y;
	int phi = blockIdx.z*blockDim.z + threadIdx.z;

	if (r<M && theta<N && phi<O){
	    int global_phi = phi + phi_offset;

        if (r == 0 || r == M-1 ){
            a[I(t, phi, theta, r)] = a_0[r] + PI_1;
            F[I(t, phi, theta, r)] = q*(dtheta*theta) + PI_2;
            G[I(t, phi, theta, r)] = p*((dt*(REAL)l)/(REAL)L - dphi*(REAL)global_phi) + PI_3;
        } else if (theta == 0 || theta == N-1 ){
            a[I(t, phi, theta, r)] = a_0[r] + PI_1;
            F[I(t, phi, theta, r)] = q*(dtheta*theta) + PI_2;
            G[I(t, phi, theta, r)] = p*((dt*(REAL)l)/(REAL)L - dphi*(REAL)global_phi) + PI_3;
        } else if (global_phi == 0 || global_phi == globalWidth-1 ){
            a[I(t, phi, theta, r)] = a_0[r] + PI_1;
            F[I(t, phi, theta, r)] = q*(dtheta*theta) + PI_2;
            G[I(t, phi, theta, r)] = p*((dt*(REAL)l)/(REAL)L - dphi*(REAL)global_phi) + PI_3;
        }
	}
}

