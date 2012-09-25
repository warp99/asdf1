#include <stdio.h>
#include <math.h>

#define GLEW_STATIC
#include "glew.h"
#include "GL/glut.h"
#include "cuda_gl_interop.h"


int window_width = 512;
int window_height = 512;
int mesh_width = 256;
int mesh_height = 256;
float anim = 0.0f;

//mouse
int mouse_old_x, mouse_old_y;
int mouse_buttons = 0;
float rotate_x = 0.0, rotate_y = 0.0;
float translate_z = -3.0;


void display();
void mouse (int button, int state, int x, int y);
void motion(int x, int y);
void deleteVBO();
__global__ void createVertices(float4* positions, float time,
								unsigned int mesh_width, unsigned int mesh_height);

GLuint positionsVBO;
struct cudaGraphicsResource *positionsVBO_CUDA;

int main(int argc, char **argv)
{
	puts("krok1");
	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE);
	glutInitWindowPosition(100,100);
	glutInitWindowSize(window_width,window_height);
	glutCreateWindow("Janix is the Mastah!");

	puts ("krok2");

	cudaGLSetGLDevice(0);
/*
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glTranslatef(0.0, 0.0, translate_z);
	glRotatef(rotate_x, 1.0, 0.0, 0.0);
	glRotatef(rotate_y, 0.0, 1.0, 0.0);
*/
	glutDisplayFunc(display);
	glutMouseFunc(mouse);
	glutMotionFunc(motion);

	glClearColor(0.0, 0.0, 0.0, 1.0);
	
	//GLEW INIT!!!
	GLenum err = glewInit();
	if (GLEW_OK != err)
	{
		fprintf(stderr, "Error: %s\n",
			glewGetErrorString(err));
	}
	fprintf(stdout, "status: using GLEW %s\n",
		glewGetString(GLEW_VERSION));
	//END GLEW!! :)
	glViewport(0, 0, window_width, window_height);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(60.0, (GLfloat)window_width / (GLfloat) window_height, 0.1, 10.0);
	

	puts("krok3");
	glGenBuffers(1, &positionsVBO);
	puts("krok4");
	glBindBuffer(GL_ARRAY_BUFFER, positionsVBO);
	puts("krok5");
	unsigned int size = mesh_width * mesh_height * 4 * sizeof(float);
	glBufferData(GL_ARRAY_BUFFER, size, 0, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	cudaGraphicsGLRegisterBuffer(&positionsVBO_CUDA, 
									positionsVBO,
									cudaGraphicsMapFlagsWriteDiscard);

	

	glutMainLoop();
	deleteVBO();

}

void display()
{
	float4* positions;
	cudaGraphicsMapResources(1, &positionsVBO_CUDA, 0);
	size_t num_bytes;
	cudaGraphicsResourceGetMappedPointer((void**)&positions, &num_bytes,
											positionsVBO_CUDA);
	dim3 dimBlock(16, 16, 1);
	dim3 dimGrid(mesh_width / dimBlock.x, mesh_height /dimBlock.y, 1);
	createVertices<<<dimGrid, dimBlock>>>(positions, anim, mesh_width, mesh_height);

	cudaGraphicsUnmapResources(1, &positionsVBO_CUDA, 0);
	
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glTranslatef(0.0, 0.0, translate_z);
	glRotatef(rotate_x, 1.0, 0.0, 0.0);
	glRotatef(rotate_y, 0.0, 1.0, 0.0);

	glBindBuffer(GL_ARRAY_BUFFER, positionsVBO);
	glVertexPointer(4, GL_FLOAT, 0, 0);
	glEnableClientState(GL_VERTEX_ARRAY);
	glDrawArrays(GL_POINTS, 0, mesh_width * mesh_height);
	glDisableClientState(GL_VERTEX_ARRAY);
	anim += 0.01f;

	glutSwapBuffers();
	glutPostRedisplay();
}

void deleteVBO()
{
	cudaGraphicsUnregisterResource(positionsVBO_CUDA);
	glDeleteBuffers(1, &positionsVBO);
}

void mouse (int button, int state, int x, int y)
{
	if (state == GLUT_DOWN)
	{
		mouse_buttons |= 1<< button;
	}
	else if (state == GLUT_UP) 
	{
		mouse_buttons = 0;
	}

	mouse_old_x = x;
	mouse_old_y = y;
}
void motion(int x, int y)
{
	float dx, dy;
	dx = (float) (x - mouse_old_x);
	dy = (float) (y - mouse_old_y);
	
	if(mouse_buttons & 1){
		rotate_x += dy * 0.2f;
		rotate_y += dx * 0.2f;
	} else if (mouse_buttons & 4) {
		translate_z += dy * 0.01f;
	}

	mouse_old_x = x;
	mouse_old_y = y;
}


/*
__device__ float3 bodyBodyInteraction(float4 bi, float4 bj, float3 ai)
{
	float3 r;
	r.x = bj.x - bi.x;
	r.y = bj.y - bi.y;
	float odleglosc = r.x * r.x + r.y * r.y;
	ai.x += odleglosc;
	ai.y += odleglosc;
	return ai;

}
*/
/*
__global__ void calculate_forces (void *devX,

positions = bodyBodyInteraction(positions, positions, time)

*/



__global__ void createVertices(float4* positions, float time,
								unsigned int mesh_width, unsigned int mesh_height)
{
	unsigned int x = blockIdx.x * blockDim.x + threadIdx.x;
	unsigned int y = blockIdx.y * blockDim.y + threadIdx.y;

	float u = x / (float) mesh_width;
	float v = y / (float) mesh_height;
	u = u * 2.0f - 1.0f;
	v = v * 2.0f - 1.0f;
	float d = sqrt(u*u + v*v);
	//float freq = 4.0f;

	float w = sinf(d * time) * cosf(d * time);
	positions[y * mesh_width + x] = make_float4(u, w, v, 1.0f);

}

