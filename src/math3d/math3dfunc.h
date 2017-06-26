#ifndef __MATH3DFUNC_H__
#define __MATH3DFUNC_H__


namespace neox
{
namespace math3d
{

template <class T> struct _Vector3;
template <class T> struct _Matrix;
template <class T> struct _Rotation;
template <class T> struct _Plane;
template <class T> struct _Line3;

template <class T>
inline T DegreeToRadian(T degree)
{
	return degree * PI / 180;
}

template <class T>
inline T RadianToDegree(T radian)
{
	return radian * 180 / PI;
}

#ifndef NEOX_ABS
#define NEOX_ABS
template <class T>
inline T Abs(T val)
{
	return (val < 0 ? -val : val);
}
#endif

inline int NextPower2(int x)
{
   int r = 1;

   while (x > r) r = r << 1;

   return r;
}

template <class T>
inline void MakeMatProjection(_Matrix<T> &mat, const _Vector3<T> &light,
	const _Plane<T> &plane, bool point_light = true)
{
	if (point_light)
	{
		// Լ�����任����������������
		// ������
		//     light �ǵ��Դλ��
		//     plane ��ͶӰƽ��
		// �㷨��
		//     ��v(vx, vy, vz)������һ���㣬p(px, py, pz)�ǵ�v��ƽ���ϵ�
		//	   ͶӰ��������У�
		//		   px = lx + t (vx - lx)
		//		   py = ly + t (vy - ly)
		//		   pz = lz + t (vz - lz)
		//	   ���У�l(lx, ly, lz)�ǵ��Դλ��
		//	   ���ǵ�p��ƽ���ϣ���
		//		   nx px + ny py + nz pz - d = 0
		//	   ���У�n(nx, ny, nz)��ͶӰƽ��ķ����������ѹ淶����
		//	   ����������ĸ�������ɵĹ���px, py, pz, t���������̣���
		//		   t = (nx lx + ny ly + nz lz - d) / D
		//		   px = [(ny ly + nz lz - d) vx + (-ny lx) vy + (-nz lx) vz + d lx] / D
		//		   py = [(-nx ly) vx + (nx lx + nz lz - d) vy + (-nz ly) vz + d ly] / D
		//		   pz = [(-nx lz) vx + (-ny lz) vy + (nx lx + ny ly - d) vz + d lz] / D
		//	   ���У�D = (nx lx + ny ly + nz lz) - (nx vx + ny vy + nz vz)

		T dot = plane.normal.Dot(light) - plane.dist;

		mat.m00 = -light.x * plane.normal.x + dot;
		mat.m10 = -light.x * plane.normal.y;
		mat.m20 = -light.x * plane.normal.z;
		mat.m30 =  light.x * plane.dist;

		mat.m01 = -light.y * plane.normal.x;
		mat.m11 = -light.y * plane.normal.y + dot;
		mat.m21 = -light.y * plane.normal.z;
		mat.m31 =  light.y * plane.dist;

		mat.m02 = -light.z * plane.normal.x;
		mat.m12 = -light.z * plane.normal.y;
		mat.m22 = -light.z * plane.normal.z + dot;
		mat.m32 =  light.z * plane.dist;

		mat.m03 = -plane.normal.x;
		mat.m13 = -plane.normal.y;
		mat.m23 = -plane.normal.z;
		mat.m33 = dot + plane.dist;
	}
	else
	{
		// ������
		//     light ��ƽ�й�Դ����
		//     plane ��ͶӰƽ��
		// �㷨��
		//     ��v(vx, vy, vz)������һ���㣬p(px, py, pz)�ǵ�v��ƽ���ϵ�
		//	   ͶӰ��������У�
		//		   px = vx + t lx
		//		   py = vy + t ly
		//		   pz = vz + t lz
		//	   ���У�l(lx, ly, lz)��ƽ�й�Դ����
		//	   ���ǵ�p��ƽ���ϣ���
		//		   nx px + ny py + nz pz - d = 0
		//	   ���У�n(nx, ny, nz)��ͶӰƽ��ķ����������ѹ淶����
		//	   ����������ĸ�������ɵĹ���px, py, pz, t���������̣���
		//		   t = (d - (nx vx + ny vy + nz vz)) / D
		//		   px = [(ny ly + nz lz) vx + (-ny lx) vy + (-nz lx) vz + d lx] / D
		//		   py = [(-nx ly) vx + (nx lx + nz lz) vy + (-nz ly) vz + d ly] / D
		//		   pz = [(-nx lz) vx + (-ny lz) vy + (nx lx + ny ly) vz + d lz] / D
		//	   ���У�D = nx lx + ny ly + nz lz

		T dot = plane.normal.Dot(light);
		T reci_dot = (T)1 / dot;
		_Vector3<T> temp(light);
		temp *= reci_dot;

		mat.m00 = -temp.x * plane.normal.x + (T)1;
		mat.m10 = -temp.x * plane.normal.y;
		mat.m20 = -temp.x * plane.normal.z;
		mat.m30 =  temp.x * plane.dist;

		mat.m01 = -temp.y * plane.normal.x;
		mat.m11 = -temp.y * plane.normal.y + (T)1;
		mat.m21 = -temp.y * plane.normal.z;
		mat.m31 =  temp.y * plane.dist;

		mat.m02 = -temp.z * plane.normal.x;
		mat.m12 = -temp.z * plane.normal.y;
		mat.m22 = -temp.z * plane.normal.z + (T)1;
		mat.m32 =  temp.z * plane.dist;

		mat.m03 = (T)0;
		mat.m13 = (T)0;
		mat.m23 = (T)0;
		mat.m33 = (T)1;
	}
}

template <class T>
inline void MakeMatReflection(_Matrix<T> &mat, const _Vector3<T> &norm,
	const _Vector3<T> &origin)
{
	// ������
	//	   norm������ƽ��ķ�����
	//	   origin������ƽ����һ��
	// Լ����norm����淶��
	// �㷨��
	// �ȼ��跴��ƽ�澭��ԭ�㣬��ƽ�淽��Ϊnx x + ny y + nz z = 0
	// ���У�(nx, ny, nz)��ƽ��ķ�����������||n|| = 1
	// ��v(vx, vy, vz)�ǿռ�����һ�㣬t��v��n֮��ļнǣ���
	//	  (n, v) = ||n|| ||v|| cos(t) = ||v|| cos(t)
	// ע�⵽����v������ƽ��ľ���Ϊ||v|| cos(t)�����Ե�v�ķ����Ϊ
	//	  v' = v - 2 ||v|| cos(t) n = v - 2 (n, v) n
	// ��
	//	  vx' = (1 - 2 nx nx) vx + (- 2 nx ny) vy + (- 2 nx nz) vz 
	//	  vy' = (-2 nx ny) vx + (1 - 2 ny ny) vy + (-2 ny nz) vz
	//	  vz' = (-2 nx nz) vx + (-2 ny nz) vy + (1 - 2 nz nz) vz
	// �ʱ任����Ϊ��
	//	  R =
	//	  [1 - 2 nx nx	   -2 ny nx	   -2 nz nx	]
	//	  [   -2 nx ny	1 - 2 ny ny	   -2 nz ny	]
	//	  [   -2 nx nz	   -2 ny nz	1 - 2 nz nz	]
	//	  [											1]
	// ��������������ƽ�治����ԭ���������跴��ƽ�澭����p(x0, y0, z0)
	// �����ǿ�����������任֮ǰ����ƽ�Ʊ任T(-p)���ڷ���任֮������
	// �任T(p)�������յı任����Ϊ��
	//	  T(-p) R T(p) =
	//	  [1 - 2 nx nx	   -2 ny nx	   -2 nz nx	]
	//	  [   -2 nx ny	1 - 2 ny ny	   -2 nz ny	]
	//	  [   -2 nx nz	   -2 ny nz	1 - 2 nz nz	]
	//	  [	2 nx d		 2 ny d		 2 nz d	1]

	T d = norm.Dot(origin);

	mat.m00 = T(-2.0 * norm.x * norm.x + 1.0);
	mat.m10 = T(-2.0 * norm.x * norm.y);
	mat.m20 = T(-2.0 * norm.x * norm.z);
	mat.m30 = T( 2.0 * norm.x * d);

	mat.m01 = T(-2.0 * norm.y * norm.x);
	mat.m11 = T(-2.0 * norm.y * norm.y + 1.0);
	mat.m21 = T(-2.0 * norm.y * norm.z);
	mat.m31 = T( 2.0 * norm.y * d);

	mat.m02 = T(-2.0 * norm.z * norm.x);
	mat.m12 = T(-2.0 * norm.z * norm.y);
	mat.m22 = T(-2.0 * norm.z * norm.z + 1.0);
	mat.m32 = T( 2.0 * norm.z * d);

	mat.m03 = (T)0;
	mat.m13 = (T)0;
	mat.m23 = (T)0;
	mat.m33 = (T)1;
}

template <class T>
inline void TransformPlane(const _Plane<T> &src, _Plane<T> &dest,
	const _Matrix<T> &mat, bool do_norm = true)
{
	_Vector3<T> start_pt;
	_Vector3<T> src_normal(src.normal);

	MulVecMat3X3(src_normal, mat, dest.normal);
	if (do_norm)
	{
		dest.normal.Normalize();
	}
	start_pt = src_normal * src.dist;
	start_pt *= mat;
	dest.dist = dest.normal.Dot(start_pt);
}

template <class T>
inline void RotationToMatrix(const _Rotation<T> &rot, _Matrix<T> &mat)
{
	T wx, wy, wz, x2, y2, z2, xy, yz, xz;
	
	wx = T(2.0 * rot.w * rot.x);
	wy = T(2.0 * rot.w * rot.y);
	wz = T(2.0 * rot.w * rot.z);

	x2 = T(2.0 * rot.x * rot.x);
	y2 = T(2.0 * rot.y * rot.y);
	z2 = T(2.0 * rot.z * rot.z);

	xy = T(2.0 * rot.x * rot.y);
	yz = T(2.0 * rot.y * rot.z);
	xz = T(2.0 * rot.x * rot.z);

	mat.m00 = (T)1 - y2 - z2;
	mat.m01 = xy + wz;
	mat.m02 = xz - wy;
	
	mat.m10 = xy - wz;
	mat.m11 = (T)1 - x2 - z2;
	mat.m12 = yz + wx;
	
	mat.m20 = xz + wy;
	mat.m21 = yz - wx;
	mat.m22 = (T)1 - x2 - y2;

	mat.m03 = mat.m13 = mat.m23 = mat.m30 = mat.m31 = mat.m32 = (T)0;
	mat.m33 = (T)1;
}

template <class T>
inline void RotationToOrient(const _Rotation<T> &rot, 
	_Vector3<T> &right, _Vector3<T> &up, _Vector3<T> &forward) 
{
	_Matrix<T> mat;
	RotationToMatrix(rot, mat);
	
	right.Set(mat.m00, mat.m01, mat.m02);
	up.Set(mat.m10, mat.m11, mat.m12);
	forward.Set(mat.m20, mat.m21, mat.m22);
}

template <class T>
inline void MatrixToRotation(const _Matrix<T> &mat, _Rotation<T> &rot)
{
	T tr, s;	
	tr = T(mat.m00 + mat.m11 + mat.m22 + (T)1);

	if (Abs(tr) < (T)EPSILON)
	{
		int i, j, k;
		static int next_index[3] = {1, 2, 0};
		
		i = 0;
		if (mat.m11 > mat.m00)
		{
			i = 1;
		}
		if (mat.m22 > mat.m[i][i])
		{
			i = 2;
		}
		
		j = next_index[i];
		k = next_index[j];

		s = (T)sqrt(mat.m[i][i] - mat.m[j][j] - mat.m[k][k] + (T)1);

		rot.q[i] = T(s * 0.5);
		s = T(0.5 / s);
		rot.w = (mat.m[j][k] - mat.m[k][j]) * s;
		rot.q[j] = (mat.m[j][i] + mat.m[i][j]) * s;
		rot.q[k] = (mat.m[k][i] + mat.m[i][k]) * s;
	}
	else
	{
		s = (T)sqrt(tr);
		
		rot.w = T(s * 0.5);
		s = T(0.5 / s);

		rot.x = (mat.m12 - mat.m21) * s;
		rot.y = (mat.m20 - mat.m02) * s;
		rot.z = (mat.m01 - mat.m10) * s;	
	}
	rot.Normalize();
}

template <class T>
inline void OrientToRotation(const _Vector3<T> &forward, const _Vector3<T> &up,
	_Rotation<T> &rot)
{
	_Matrix<T> mat;
	MakeMatOrient(mat, forward, up);
	MatrixToRotation(mat, rot);
}

enum
{
	EULER_ORDER_XYZ = 1,
	EULER_ORDER_YZX = 2,
	EULER_ORDER_ZXY = 3,
	EULER_ORDER_XZY = 4,
	EULER_ORDER_YXZ = 5,
	EULER_ORDER_ZYX = 6
};

// ����������ת������ŷ����ת��, ��Χ��-PI �� PI
template <class T>
inline void EulerToMatrixLH(T x, T y, T z, _Matrix<T> &mat)
{
	mat.Set(
		cos(-z) * cos(-y), cos(-z) * sin(-y) * sin(-x) - sin(-z) * cos(-x), cos(-z) * sin(-y) * cos(-x) + sin(-z) * sin(-x), 0.0f,
		sin(-z) * cos(-y), sin(-z) * sin(-y) * sin(-x) + cos(-z) * cos(-x), sin(-z) * sin(-y) * cos(-x) - cos(-z) * sin(-x), 0.0f,
		-sin(-y), cos(-y) * sin(-x), cos(-y) * cos(-x), 0.0f,
		0.0f, 0.0f, 0.0f, 1.0f
		);
}

template <class T>
inline void MatrixToEulerLH(const _Matrix<T> &mat, T &x, T &y, T &z)
{
	// �Ӿ����еó�eular��,��Ϊ�������������ֵģ�����,���Խ��Ҫȡ������������
	z = -atan2(mat.m10, mat.m11);
	y = -atan2(-mat.m20, sqrt(mat.m21 * mat.m21 + mat.m22 * mat.m22));
	x = -atan2(mat.m21, mat.m22);
}


template <class T>
inline void EulerToMatrix(T x_angle, T y_angle, T z_angle, _Matrix<T> &mat,
	int euler_order = EULER_ORDER_YZX)
{
	T xc = (T)cos(x_angle), xs = (T)sin(x_angle);
	T yc = (T)cos(y_angle), ys = (T)sin(y_angle);
	T zc = (T)cos(z_angle), zs = (T)sin(z_angle);

	switch (euler_order)
	{
	case EULER_ORDER_XYZ:
		mat.m00 = yc * zc;
		mat.m10 = -xc * zs + zc * xs * ys;
		mat.m20 = xs * zs + xc * zc * ys;

		mat.m01 = yc * zs;
		mat.m11 = xc * zc + xs * ys * zs;
		mat.m21 = -xs * zc + xc * ys * zs;

		mat.m02 = -ys;
		mat.m12 = xs * yc;
		mat.m22 = xc * yc;
		break;

	case EULER_ORDER_YZX:
		mat.m00 = yc * zc;
		mat.m10 = -zs;
		mat.m20 = ys * zc;

		mat.m01 = ys * xs + yc * zs * xc;
		mat.m11 = zc * xc;
		mat.m21 = -yc * xs + ys * zs * xc;

		mat.m02 = -ys * xc + yc * zs * xs;
		mat.m12 = zc * xs;
		mat.m22 = yc * xc + ys * zs * xs;
		break;

	case EULER_ORDER_ZXY:
		mat.m00 = zc * yc + zs * xs * ys;
		mat.m10 = -zs * yc + zc * xs * ys;
		mat.m20 = xc * ys;

		mat.m01 = zs * xc;
		mat.m11 = zc * xc;
		mat.m21 = -xs;

		mat.m02 = -zc * ys + zs * xs * yc;
		mat.m12 = zs * ys + zc * xs * yc;
		mat.m22 = xc * yc;
		break;

	case EULER_ORDER_XZY:
		mat.m00 = zc * yc;
		mat.m10 = xs * ys - xc * zs * yc;
		mat.m20 = xc * ys + xs * zs * yc;

		mat.m01 = zs;
		mat.m11 = xc * zc;
		mat.m21 = -xs * zc;

		mat.m02 = -zc * ys;
		mat.m12 = xs * yc + xc * zs * ys;
		mat.m22 = xc * yc - xs * zs * ys;
		break;

	case EULER_ORDER_YXZ:
		mat.m00 = yc * zc - ys * xs * zs;
		mat.m10 = -xc * zs;
		mat.m20 = ys * zc + yc * xs * zs;

		mat.m01 = yc * zs + ys * xs * zc;
		mat.m11 = xc * zc;
		mat.m21 = ys * zs - yc * xs * zc;

		mat.m02 = -ys * xc;
		mat.m12 = xs;
		mat.m22 = yc * xc;
		break;

	case EULER_ORDER_ZYX:
		mat.m00 = zc * yc;
		mat.m10 = -zs * yc;
		mat.m20 = ys;

		mat.m01 = zs * xc + zc * ys * xs;
		mat.m11 = zc * xc - zs * ys * xs;
		mat.m21 = -yc * xs;

		mat.m02 = zs * xs - zc * ys * xc;
		mat.m12 = zc * xs + zs * ys * xc;
		mat.m22 = yc * xc;
		break;
	}

	mat.m03 = mat.m13 = mat.m23 = (T)0;
	mat.m30 = mat.m31 = mat.m32 = (T)0;
	mat.m33 = (T)1;
}

template <class T>
inline void MatrixToEuler(const _Matrix<T> &mat, T &x_angle, T &y_angle, T &z_angle,
	int euler_order = EULER_ORDER_YZX)
{
	// ע�⣺ŷ����˳������˽���Ƕȵķ�Χ��
	// �����м�����Ӧ����ת����(-PI / 2, PI / 2]֮�䣬
	// ����������ת����(-PI, PI]֮�䡣
	// ���磺euler_order = EULER_ORDER_YZX ʱ��
	// -PI < x_angle <= PI
	// -PI < y_angle <= PI
	// -PI / 2 < z_angle <= PI / 2

	T xs, ys, zs;
	switch (euler_order)
	{
	case EULER_ORDER_XYZ:
		ys = -mat.m02;
		if (ys <= (T)-1)
		{
			y_angle = T(-PI / 2);
		}
		else if (ys >= (T)1)
		{
			y_angle = T(PI / 2);
		}
		else
		{
			y_angle = (T)asin(ys);
		}
		if (ys > T(1 - EPSILON))
		{
			z_angle = (T)0;
			x_angle = (T)atan2(-mat.m21, mat.m11);
		}
		else
		{
			z_angle = (T)atan2(mat.m01, mat.m00);
			x_angle = (T)atan2(mat.m12, mat.m22);
		}
		break;

	case EULER_ORDER_YZX:
		zs = -mat.m10;
		if (zs <= (T)-1)
		{
			z_angle = T(-PI / 2);
		}
		else if (zs >= (T)1)
		{
			z_angle = T(PI / 2);
		}
		else
		{
			z_angle = (T)asin(zs);
		}
		if (zs > T(1 - EPSILON))
		{
			x_angle = (T)0;
			y_angle = (T)atan2(-mat.m02, mat.m22);
		}
		else
		{
			x_angle = (T)atan2(mat.m12, mat.m11);
			y_angle = (T)atan2(mat.m20, mat.m00);
		}
		break;

	case EULER_ORDER_ZXY:
		xs = -mat.m21;
		if (xs <= (T)-1)
		{
			x_angle = T(-PI / 2);
		}
		else if (xs >= (T)1)
		{
			x_angle = T(PI / 2);
		}
		else
		{
			x_angle = (T)asin(xs);
		}
		if (xs > T(1 - EPSILON))
		{
			y_angle = (T)0;
			z_angle = (T)atan2(-mat.m10, mat.m00);
		}
		else
		{
			y_angle = (T)atan2(mat.m20, mat.m22);
			z_angle = (T)atan2(mat.m01, mat.m11);
		}
		break;

	case EULER_ORDER_XZY:
		zs = mat.m01;
		if (zs <= (T)-1)
		{
			z_angle = T(-PI / 2);
		}
		else if (zs >= (T)1)
		{
			z_angle = T(PI / 2);
		}
		else
		{
			z_angle = (T)asin(zs);
		}
		if (zs > T(1 - EPSILON))
		{
			y_angle = (T)0;
			x_angle = (T)atan2(mat.m12, mat.m22);
		}
		else
		{
			y_angle = (T)atan2(-mat.m02, mat.m00);
			x_angle = (T)atan2(-mat.m21, mat.m11);
		}
		break;

	case EULER_ORDER_YXZ:
		xs = mat.m12;
		if (xs <= (T)-1)
		{
			x_angle = T(-PI / 2);
		}
		else if (xs >= (T)1)
		{
			x_angle = T(PI / 2);
		}
		else
		{
			x_angle = (T)asin(xs);
		}
		if (xs > T(1 - EPSILON))
		{
			z_angle = (T)0;
			y_angle = (T)atan2(mat.m20, mat.m00);
		}
		else
		{
			z_angle = (T)atan2(-mat.m10, mat.m11);
			y_angle = (T)atan2(-mat.m02, mat.m22);
		}
		break;

	case EULER_ORDER_ZYX:
		ys = mat.m20;
		if (ys <= (T)-1)
		{
			y_angle = T(-PI / 2);
		}
		else if (ys >= (T)1)
		{
			y_angle = T(PI / 2);
		}
		else
		{
			y_angle = (T)asin(ys);
		}
		if (ys > T(1 - EPSILON))
		{
			x_angle = (T)0;
			z_angle = (T)atan2(mat.m01, mat.m11);
		}
		else
		{
			x_angle = (T)atan2(-mat.m21, mat.m22);
			z_angle = (T)atan2(-mat.m10, mat.m00);
		}
		break;
	}
}

template <class T>
inline void EulerToMatrix(const _Vector3<T> &euler_angle, _Matrix<T> &mat,
	int euler_order = EULER_ORDER_YZX)
{
	EulerToMatrix(euler_angle.x, euler_angle.y, euler_angle.z, mat, euler_order);
}

template <class T>
inline void MatrixToEuler(const _Matrix<T> &mat, _Vector3<T> &euler_angle,
	int euler_order = EULER_ORDER_YZX)
{
	MatrixToEuler(mat, euler_angle.x, euler_angle.y, euler_angle.z, euler_order);
}

template <class T>
inline void EulerToRotation(T x_angle, T y_angle, T z_angle, _Rotation<T> &rot,
	int euler_order = EULER_ORDER_YZX)
{
	_Matrix<T> mat;
	EulerToMatrix(x_angle, y_angle, z_angle, mat, euler_order);
	MatrixToRotation(mat, rot);
}

template <class T>
inline void RotationToEuler(const _Rotation<T> &rot, T &x_angle, T &y_angle, T &z_angle,
	int euler_order = EULER_ORDER_YZX)
{
	_Matrix<T> mat;
	RotationToMatrix(rot, mat);
	MatrixToEuler(mat, x_angle, y_angle, z_angle, euler_order);
}

template <class T>
inline void EulerToRotation(const _Vector3<T> &euler_angle, _Rotation<T> &rot,
	int euler_order = EULER_ORDER_YZX)
{
	EulerToRotation(euler_angle.x, euler_angle.y, euler_angle.z, rot, euler_order);
}

template <class T>
inline void RotationToEuler(const _Rotation<T> &rot, _Vector3<T> &euler_angle,
	int euler_order = EULER_ORDER_YZX)
{
	RotationToEuler(rot, euler_angle.x, euler_angle.y, euler_angle.z, euler_order);
}

template <class T>
inline void RotatePointByLine(_Vector3<T> &dest, const _Vector3<T> &src,
	const _Line3<T> &axis, T angle)
{
	_Vector3<T> axis_dir = axis.dir;
	axis_dir.Normalize();
	_Matrix<T> rot_mat;
	MakeMatRotation(rot_mat, axis_dir, angle);
	dest = src;
	dest -= axis.p0;
	dest *= rot_mat;
	dest += axis.p0;
}

// �߶��������ε��ཻ�ж�
template <class T>
bool LineSegHitTriangle(const _Line3<T> &ray, const _Vector3<T> &a, const _Vector3<T> &b,
	const _Vector3<T> &c, T &min_t, bool cull_back = true)
{
	// ���߱���淶�������򽫵������� IntersectPlane �����tֵ����ȷ
	_Plane<T> tri_plane;
	tri_plane.Set(a, b, c);

	// ���Ż���ray.dir�ĳ��Ƚ�Сʱ�ᵼ�½������
	//v1.Cross(v2, tri_plane.normal);
	//T d = a.x * (b.y * c.z - b.z * c.y)
	//	- a.y * (b.x * c.z - b.z * c.x)
	//	+ a.z * (b.x * c.y - b.y * c.x);
	//tri_plane.dist = d;

	// CCW�޳���ʽ�¹��˱���
	if (cull_back && ray.dir.Dot(tri_plane.normal) >= 0.0f)
	{
		return false;
	}

	// �������
	T t;
	if (ray.IntersectPlane(tri_plane, t) != LINE_INTERSECT_SOMEWHERE ||
		t < 0.0f || t > min_t)
	{
		return false;
	}

	// ���㽻��
	_Vector3<T> hit_point;
	ray.Evaluate(t, hit_point);

	// �жϽ����Ƿ�����������
	if (!PointInTriangle(hit_point, a, b, c))
	{
		return false;
	}

	min_t = t;
	return true;
}

} // namespace math3d
} // namespace neox


#endif // __MATH3DFUNC_H__
