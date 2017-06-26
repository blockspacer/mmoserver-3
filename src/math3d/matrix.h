#pragma once

#ifndef __MATRIX_H__
#define __MATRIX_H__

#include <math.h>
#include "mathconsts.h"

namespace neox
{
namespace math3d
{

template <class T>
struct _Matrix;

template <class T>
inline void DoMulScaleMat(const T &scale, const _Matrix<T> &mat, _Matrix<T> &prod);
inline void DoMulScaleMat(const Float &scale, const _Matrix<Float> &mat, _Matrix<Float> &prod);

template <class T>
inline void DoMulMat(const _Matrix<T> &mat1, const _Matrix<T> &mat2, _Matrix<T> &prod);
inline void DoMulMat(const _Matrix<Float> &mat1, const _Matrix<Float> &mat2, _Matrix<Float> &prod);

template <class T>
inline bool DoInverseMat(_Matrix<T> &mat, T *determinant = NULL);
inline bool DoInverseMat(_Matrix<Float> &mat, Float *determinant = NULL);

template <class T>
inline void DoMulVecMat(const _Vector3<T> &vec, const _Matrix<T> &mat, _Vector3<T> &prod);
inline void DoMulVecMat(const _Vector3<Float> &vec, const _Matrix<Float> &mat, _Vector3<Float> &prod);

template <class T>
inline void DoMulVecMat3X3(const _Vector3<T> &vec, const _Matrix<T> &mat, _Vector3<T> &prod);
inline void DoMulVecMat3X3(const _Vector3<Float> &vec, const _Matrix<Float> &mat, _Vector3<Float> &prod);

template <class T>
inline T DoTransformVec(_Vector3<T> &vec, const _Matrix<T> &mat);
inline Float DoTransformVec(_Vector3<Float> &vec, const _Matrix<Float> &mat);

template <class T>
inline void DoAddMatScaled(_Matrix<T> &dest, const _Matrix<T> &mat, const T &scale);
inline void DoAddMatScaled(_Matrix<Float> &dest, const _Matrix<Float> &mat, const Float &scale);


#ifndef NEOX_ABS
#define NEOX_ABS
template <class T>
inline T Abs(T val)
{
	return (val < 0 ? -val : val);
}
#endif


const int N = 4;

// 4X4矩阵，使用左手坐标系

template <class T>
#ifdef NEOX
struct _Matrix: public Align16
#else
struct _Matrix
#endif
{
	struct _Vector;

	union
	{
		T m[N][N];
		T v[N * N];
		struct
		{
			T m00, m01, m02, m03;
			T m10, m11, m12, m13;
			T m20, m21, m22, m23;
			T m30, m31, m32, m33;
		};
	};

	_Matrix(int i = -1)
	{
		if (i == 1)
		{
			SetIdentity();
		}
		else if (i == 0)
		{
			Set((T)0, (T)0, (T)0, (T)0,
				(T)0, (T)0, (T)0, (T)0,
				(T)0, (T)0, (T)0, (T)0,
				(T)0, (T)0, (T)0, (T)0);
		}
	}

	_Matrix(const T &_m00, const T &_m01, const T &_m02, const T &_m03, 
		const T &_m10, const T &_m11, const T &_m12, const T &_m13, 
		const T &_m20, const T &_m21, const T &_m22, const T &_m23, 
		const T &_m30, const T &_m31, const T &_m32, const T &_m33): 
		m00(_m00), m01(_m01), m02(_m02), m03(_m03), 
		m10(_m10), m11(_m11), m12(_m12), m13(_m13), 
		m20(_m20), m21(_m21), m22(_m22), m23(_m23), 
		m30(_m30), m31(_m31), m32(_m32), m33(_m33)
	{}

	void Init(const T &_m00, const T &_m01, const T &_m02, const T &_m03, 
		const T &_m10, const T &_m11, const T &_m12, const T &_m13, 
		const T &_m20, const T &_m21, const T &_m22, const T &_m23, 
		const T &_m30, const T &_m31, const T &_m32, const T &_m33)
	{
		Set(_m00, _m01, _m02, _m03, 
			_m10, _m11, _m12, _m13, 
			_m20, _m21, _m22, _m23, 
			_m30, _m31, _m32, _m33);
	}

	void Set(const T &_m00, const T &_m01, const T &_m02, const T &_m03, 
		const T &_m10, const T &_m11, const T &_m12, const T &_m13, 
		const T &_m20, const T &_m21, const T &_m22, const T &_m23, 
		const T &_m30, const T &_m31, const T &_m32, const T &_m33)
	{
		m00 = _m00, m01 = _m01, m02 = _m02, m03 = _m03;
		m10 = _m10, m11 = _m11, m12 = _m12, m13 = _m13;
		m20 = _m20, m21 = _m21, m22 = _m22, m23 = _m23;
		m30 = _m30, m31 = _m31, m32 = _m32, m33 = _m33;
	}

	void Set3X3(const _Matrix<T> &mat)
	{
		m00 = mat.m00;
		m01 = mat.m01;
		m02 = mat.m02;

		m10 = mat.m10;
		m11 = mat.m11;
		m12 = mat.m12;

		m20 = mat.m20;
		m21 = mat.m21;
		m22 = mat.m22;
	}

	void SetIdentity()
	{
		Set((T)1, (T)0, (T)0, (T)0,
			(T)0, (T)1, (T)0, (T)0,
			(T)0, (T)0, (T)1, (T)0,
			(T)0, (T)0, (T)0, (T)1);
	}

	void SetTranslation(const _Vector3<T> &pos)
	{
		SetTranslation(pos.x, pos.y, pos.z);
	}

	void SetTranslation(const T &x, const T &y, const T &z)
	{
		m30 = x;
		m31 = y;
		m32 = z;
	}

	void SetTranslating(const T &x, const T &y, const T &z)
	{
		Set((T)1, (T)0, (T)0, (T)0,
			(T)0, (T)1, (T)0, (T)0,
			(T)0, (T)0, (T)1, (T)0,
			(T)x, (T)y, (T)z, (T)1);
	}

	void SetNoTranslation()
	{
		m30 = m31 = m32 = 0;
		m33 = 1;
	}

	void SetRotation(const _Matrix<T> &rot_mat)
	{
		SetNoRotation();
		Rotate(rot_mat);
	}

	void SetNoRotation()
	{
		_Vector3<T> vec0, vec1, vec2;
		GetBasisVectors(vec0, vec1, vec2);

		m00 = vec0.Length();
		m01 = (T)0;
		m02 = (T)0;

		m10 = (T)0;
		m11 = vec1.Length();
		m12 = (T)0;

		m20 = (T)0;
		m21 = (T)0;
		m22 = vec2.Length();

		if (IsMirrored())
		{
			m00 = -m00;
		}
	}

	void SetRotating(const _Matrix<T> &rot_mat)
	{
		Set3X3(rot_mat);
		SetNoTranslation();
		m03 = m13 = m23 = 0;
	}

	void SetScale(const _Vector3<T> &scale)
	{
		SetScale(scale.x, scale.y, scale.z);
	}

	void SetScale(T scale_x, T scale_y, T scale_z)
	{
		SetNoScale();
		Scale(scale_x, scale_y, scale_z);
	}

	void SetNoScale()
	{
		_Vector3<T> vec0, vec1, vec2;
		GetBasisVectors(vec0, vec1, vec2);
		vec0.Normalize();
		vec1.Normalize();
		vec2.Normalize();
		SetBasisVectors(vec0, vec1, vec2);

		if (IsMirrored())
		{
			Mirror();
		}
	}

	void SetScaling(T scale_x, T scale_y, T scale_z)
	{
		Set(scale_x, (T)0, (T)0, (T)0, 
			(T)0, scale_y, (T)0, (T)0, 
			(T)0, (T)0, scale_z, (T)0, 
			(T)0, (T)0, (T)0, (T)1);
	}

	bool IsOrthogonal()
	{
		_Vector3<T> vec0, vec1, vec2;
		GetBasisVectors(vec0, vec1, vec2);
		if (Abs(vec0.Dot(vec1)) > EPSILON)
		{
			return false;
		}
		if (Abs(vec0.Dot(vec2)) > EPSILON)
		{
			return false;
		}
		if (Abs(vec1.Dot(vec2)) > EPSILON)
		{
			return false;
		}
		return true;
	}

	void Orthogonalize()
	{
		_Vector3<T> vec0, vec1, vec2, temp;
		GetBasisVectors(vec0, vec1, vec2);

		T len0 = vec0.Length();
		T len1 = vec1.Length();
		T len2 = vec2.Length();

		temp = vec0;
		vec1.Cross(vec2, vec0);
		vec2.Cross(vec0, vec1);
		vec0.Normalize();
		vec1.Normalize();
		vec2.Normalize();

		if (temp.Dot(vec0) < 0)
		{
			vec0 = -vec0;
		}
		vec0 *= len0;
		vec1 *= len1;
		vec2 *= len2;

		SetBasisVectors(vec0, vec1, vec2);
	}

	void SetBasisVectors(const _Vector3<T> &vec0, const _Vector3<T> &vec1,
		const _Vector3<T> &vec2) 
	{
		m00 = vec0.x;
		m01 = vec0.y;
		m02 = vec0.z;

		m10 = vec1.x;
		m11 = vec1.y;
		m12 = vec1.z;
		
		m20 = vec2.x;
		m21 = vec2.y;
		m22 = vec2.z;
	}

	void SetBasisVectors2(const _Vector3<T> &vec0, const _Vector3<T> &vec1,
		const _Vector3<T> &vec2) 
	{
		Set(vec0.x, vec0.y, vec0.z, (T)0, 
			vec1.x, vec1.y, vec1.z, (T)0, 
			vec2.x, vec2.y, vec2.z, (T)0, 
			(T)0, (T)0, (T)0, (T)1);
	}

	void GetTranslation(_Vector3<T> &pos) const
	{
		pos.Set(m30, m31, m32);
	}

	void GetRotation(_Matrix<T> &rot_mat) const
	{
		_Vector3<T> pos, scale;
		Decompose(pos, rot_mat, scale);
	}

	void GetScale(_Vector3<T> &scale) const
	{
		_Vector3<T> vec0, vec1, vec2;
		GetBasisVectors(vec0, vec1, vec2);
		
		scale.Set(vec0.Length(), vec1.Length(), vec2.Length());
		if (IsMirrored())
		{
			scale.x = -scale.x;
		}
	}

	bool HasScale() const
	{
		if (Abs(m00 * m00 + m01 * m01 + m02 * m02 - 1.0f) > EPSILON * 2)
		{
			return true;
		}
		if (Abs(m10 * m10 + m11 * m11 + m12 * m12 - 1.0f) > EPSILON * 2)
		{
			return true;
		}
		if (Abs(m20 * m20 + m21 * m21 + m22 * m22 - 1.0f) > EPSILON * 2)
		{
			return true;
		}
		return IsMirrored();
	}

	void GetBasisVectors(_Vector3<T> &vec0, _Vector3<T> &vec1, _Vector3<T> &vec2) const
	{
		vec0.Set(m00, m01, m02);
		vec1.Set(m10, m11, m12);
		vec2.Set(m20, m21, m22);
	}

	void GetRight(_Vector3<T> &right) const
	{
		right.Set(m00, m01, m02);
	}

	void GetUp(_Vector3<T> &up) const
	{
		up.Set(m10, m11, m12);
	}

	void GetForward(_Vector3<T> &forward) const
	{
		forward.Set(m20, m21, m22);
	}

	bool IsMirrored() const
	{
		_Vector3<T> vec0, vec1, vec2;
		GetBasisVectors(vec0, vec1, vec2);

		_Vector3<T> cross;
		vec0.Cross(vec1, cross);
		return vec2.Dot(cross) < (T)0;
	}

	void Compose(const _Vector3<T> &pos, const _Matrix<T> &rot_mat,
		const _Vector3<T> &scale)
	{
		SetScaling(scale.x, scale.y, scale.z);
		Rotate(rot_mat);
		SetTranslation(pos);
	}

	void Decompose(_Vector3<T> &pos, _Matrix<T> &rot_mat, _Vector3<T> &scale) const
	{
		GetTranslation(pos);

		_Vector3<T> vec0, vec1, vec2;
		GetBasisVectors(vec0, vec1, vec2);
		scale.Set(vec0.Length(), vec1.Length(), vec2.Length());

		bool is_mirrored = IsMirrored();

		vec0 /= scale.x;
		vec1 /= scale.y;
		vec2 /= scale.z;
		rot_mat.SetBasisVectors2(vec0, vec1, vec2);

		if (is_mirrored)
		{
			rot_mat.Mirror();
			scale.x = -scale.x;
		}
	}

	void Translate(const _Vector3<T> &mov)
	{
		Translate(mov.x, mov.y, mov.z);
	}

	void Translate(T mov_x, T mov_y, T mov_z)
	{
		m30 += mov_x;
		m31 += mov_y;
		m32 += mov_z;
	}

	void Rotate(const _Matrix<T> &rot_mat)
	{
		MulMat3X3InPlace(*this, rot_mat);
	}

	void Scale(const _Vector3<T> &scale)
	{
		Scale(scale.x, scale.y, scale.z);
	}

	void Scale(T scale_x, T scale_y, T scale_z)
	{
		m00 *= scale_x;
		m01 *= scale_x;
		m02 *= scale_x;

		m10 *= scale_y;
		m11 *= scale_y;
		m12 *= scale_y;

		m20 *= scale_z;
		m21 *= scale_z;
		m22 *= scale_z;
	}

	// 以yz平面为镜面做镜面变换
	void Mirror()
	{
		m00 = -m00;
		m01 = -m01;
		m02 = -m02;
		m03 = -m03;
	}

	void Normalize()
	{
		_Vector3<T> vec0, vec1, vec2;
		GetBasisVectors(vec0, vec1, vec2);

		vec1.Cross(vec2, vec0);
		vec2.Cross(vec0, vec1);
		vec0.Normalize();
		vec1.Normalize();
		vec2.Normalize();

		SetBasisVectors(vec0, vec1, vec2);
	}

	void Transpose()
	{
		Swap(m01, m10);
		Swap(m02, m20);
		Swap(m03, m30);
		Swap(m12, m21);
		Swap(m13, m31);
		Swap(m23, m32);
	}

	void Transpose3X3()
	{
		Swap(m01, m10);
		Swap(m02, m20);
		Swap(m12, m21);
	}

	bool Inverse() 
	{
		return DoInverseMat(*this);
	}

	T* operator [](int index)
	{
		return (T*)m[index];
	}

	bool operator ==(const _Matrix &mat) const
	{
		return IsEqual(mat);			
	}

	bool operator !=(const _Matrix &mat) const
	{
		return !(*this == mat);
	}

	_Matrix& operator +=(const _Matrix &mat)
	{
		for (int i = 0; i < N * N; ++i)
		{
			v[i] += mat.v[i];
		}
		return *this;
	}

	_Matrix& operator *=(const T &scale)
	{
		DoMulScaleMat<Float>(scale, *this, *this);
		return *this;
	}

	_Matrix& operator *=(const _Matrix &mat)
	{
		DoMulMat(*this, mat, *this);
		return *this;
	}

	bool IsEqual(const _Matrix &mat, const T &eps = EPSILON) const
	{
		for (int i = 0; i < N * N; ++i)
		{
			if (Abs<T>(v[i] - mat.v[i]) > eps)
			{
				return false;
			}
		}
		return true;
	}

	void AddScaled(const _Matrix &mat, const T &scale)
	{
		DoAddMatScaled(*this, mat, scale);
	}

	void Add3X3InPlace(const _Matrix &mat)
	{
		for (int i = 0; i < 3; ++i)
		{
			for (int j = 0; j < 3; ++j)
			{
				m[i][j] += mat.m[i][j];
			}
		}
	}

	void Add3X3(const _Matrix &mat, _Matrix &sum) const
	{
		for (int i = 0; i < 3; ++i)
		{
			for (int j = 0; j < 3; ++j)
			{
				sum.m[i][j] = m[i][j] + mat.m[i][j];
			}
		}
	}

private:
	void Swap(T &num1, T &num2)
	{
		T temp = num1;
		num1 = num2;
		num2 = temp;
	}

};


template <class T>
inline void MakeMatTranslation(_Matrix<T> &mat, const _Vector3<T> &pos) 
{
	mat.SetTranslating(pos.x, pos.y, pos.z);
}

template <class T>
inline void MakeMatTranslation(_Matrix<T> &mat, T pos_x, T pos_y, T pos_z) 
{
	mat.SetTranslating(pos_x, pos_y, pos_z);
}

template <class T>
inline void MakeMatRotationX(_Matrix<T> &mat, T angle)
{
	mat.SetIdentity();

	T sin_val = (T)sin(angle);
	T cos_val = (T)cos(angle);

	mat.m11 = cos_val;
	mat.m12 = sin_val;

	mat.m21 = -sin_val;
	mat.m22 = cos_val;
}

template <class T>
inline void MakeMatRotationY(_Matrix<T> &mat, T angle)
{
	mat.SetIdentity();

	T sin_val = (T)sin(angle);
	T cos_val = (T)cos(angle);

	mat.m00 = cos_val;
	mat.m02 = -sin_val;

	mat.m20 = sin_val;
	mat.m22 = cos_val;
}

template <class T>
inline void MakeMatRotationZ(_Matrix<T> &mat, T angle)
{
	mat.SetIdentity();

	T sin_val = (T)sin(angle);
	T cos_val = (T)cos(angle);

	mat.m00 = cos_val;
	mat.m01 = sin_val;

	mat.m10 = -sin_val;
	mat.m11 = cos_val;
}

template <class T>
inline void MakeMatRotation(_Matrix<T> &mat, const _Vector3<T> &axis, T angle)
{
	// 约束：<x, y, z>必须被规范化
	//	   <x, y, z>是左手坐标系
	// 算法：以右手坐标系为例。假设<x, y, z>是待转换的点，
	//	   <nx, ny, nz>是旋转所绕的轴。
	//	   首先把<nx, ny, nz>作两次旋转变换为<1, 0, 0>，
	//	   同时旋转<x, y, z>。
	//	   其中，两次旋转分别是：
	//		 1. 绕z轴顺时针旋转theta角（theta = arctg y / x）
	//		 2. 绕y轴顺时针旋转phi角（phi = arctg z）
	//	   这时我们容易对<1, 0, 0>作旋转（同时对<x', y', z'>作旋转）
	//	   旋转的结果，再以相反顺序做上面的两次旋转（角度相反）
	//	   因此，容易推得变换矩阵是：
	//		   Rz(-theta) Ry(-phi) Rx(angle) Ry(phi) Rz(theta)
	//	   把矩阵展开，并使用x, y, z值表示theta和phi的三角函数值，
	//	   并使用恒等式x^2 + y^2 + z^2 = 1，可以简化得到答案。
	//
	//	   对于左手坐标系，以(-z)替换z并化简即可。
	T sin_val, cos_val, temp;
	T cx, cy, cz;
	T sx, sy, sz;

	sin_val = (T)sin(angle);
	cos_val = (T)cos(angle);
	temp = (T)1 - cos_val;

	cx = temp * axis.x, cy = temp * axis.y, cz = temp * axis.z;
	sx = sin_val * axis.x, sy = sin_val * axis.y, sz = sin_val * axis.z;

	mat.m00 = cx * axis.x + cos_val;
	mat.m01 = cx * axis.y + sz;
	mat.m02 = cx * axis.z - sy;

	mat.m10 = cy * axis.x - sz;
	mat.m11 = cy * axis.y + cos_val;
	mat.m12 = cy * axis.z + sx;

	mat.m20 = cz * axis.x + sy;
	mat.m21 = cz * axis.y - sx;
	mat.m22 = cz * axis.z + cos_val;

	//Make the unfilled parts identity.
	mat.m30 = mat.m31 = mat.m32 = mat.m03 = mat.m13 = mat.m23 = (T)0;
	mat.m33 = (T)1;
}

template <class T>
inline void MakeMatOrient(_Matrix<T> &mat, const _Vector3<T> &forward, const _Vector3<T> &up)
{
	_Vector3<T> f, u;
	f = forward;
	u = up;
	f.Normalize();
	u.Normalize();

	T dot = f.Dot(u);
	if (dot > T(1 - EPSILON) || dot < T(-1 + EPSILON))
	{
		// 前向量和上向量平行时重新生成上向量
		_Vector3<T> f_abs(f);
		f_abs.Absolutize();
		u.Set((T)1, (T)0, (T)0);
		T min = f_abs.x;
		if (min > f_abs.y)
		{
			u.Set((T)0, (T)1, (T)0);
			min = f_abs.y;
		}
		if (min > f_abs.z)
		{
			u.Set((T)0, (T)0, (T)1);
		}
	}

	_Vector3<T> right, true_up;
	u.Cross(f, right);
	right.Normalize();
	f.Cross(right, true_up);

	mat.SetBasisVectors2(right, true_up, f);
}

template <class T>
inline void MakeMatRotation(_Matrix<T> &dest, const _Matrix<T> &src)
{
	dest.SetRotating(src);
}

template <class T>
inline void MakeMatScale(_Matrix<T> &mat, const _Vector3<T> &scale)
{
	mat.SetScaling(scale.x, scale.y, scale.z);
}

template <class T>
inline void MakeMatScale(_Matrix<T> &mat, T scale_x, T scale_y, T scale_z)
{
	mat.SetScaling(scale_x, scale_y, scale_z);
}

template <class T>
inline void MakeMatInvTransform(_Matrix<T> &dest, const _Matrix<T> &src)
{
	_Vector3<T> old_trans, new_trans;

	old_trans.x = src.m30;
	old_trans.y = src.m31;
	old_trans.z = src.m32;

	//Transpose the upper 3x3.
	dest.m00 = src.m00;  dest.m01 = src.m10; dest.m02 = src.m20;
	dest.m10 = src.m01;  dest.m11 = src.m11; dest.m12 = src.m21;
	dest.m20 = src.m02;  dest.m21 = src.m12; dest.m22 = src.m22;

	MulVecMat3X3(old_trans, dest, new_trans);
	dest.m30 = -new_trans.x;
	dest.m31 = -new_trans.y;
	dest.m32 = -new_trans.z;

	//Fill in the right col.
	dest.m03 = dest.m13 = dest.m23 = (T)0;
	dest.m33 = (T)1;
}

template <class T>
inline void MakeMatPersp(_Matrix<T> &dest, T fov_y, T aspect, T min_z, T max_z)
{
	memset(&dest, 0, sizeof(dest));
	dest.m11 = (T)1 / tan(fov_y / 2);
	dest.m00 = dest.m11 / aspect;
	dest.m22 = max_z / (max_z - min_z);
	dest.m32 = -min_z * dest.m22;
	dest.m23 = (T)1;
}

template <class T>
inline void MakeMatOrtho(_Matrix<T> &dest, T w, T h, T min_z, T max_z)
{
	memset(&dest, 0, sizeof(dest));
	dest.m00 = (T)2 / w;
	dest.m11 = (T)2 / h;
	dest.m22 = (T)1 / (max_z - min_z);
	dest.m32 = -min_z * dest.m22;
	dest.m33 = (T)1;
}

template <class T>
inline void MulScaleMat(const T &scale, const _Matrix<T> &mat, _Matrix<T> &prod)
{
	DoMulScaleMat(scale, mat, prod);
}

template <class T>
inline void MulMatScale(const _Matrix<T> &mat, const T &scale, _Matrix<T> &prod)
{
	DoMulScaleMat(mat, scale, prod);
}

template <class T>
inline void MulMatrix(const _Matrix<T> &mat1, const _Matrix<T> &mat2, _Matrix<T> &prod)
{
	DoMulMat(mat1, mat2, prod);
}

template <class T>
inline void MulMat3X3InPlace(_Matrix<T> &mat1, const _Matrix<T> &mat2)
{
	_Matrix<T> temp;
	temp.SetRotating(mat2);
	mat1 *= temp;
}

template <class T>
inline void MulMat3X3(const _Matrix<T> &mat1, const _Matrix<T> &mat2, _Matrix<T> &prod)
{
	prod = mat1;
	MulMat3X3InPlace(prod, mat2);
}

template <class T>
inline _Vector3<T>& operator *=(_Vector3<T> &vec, const _Matrix<T> &mat)
{
	DoMulVecMat(vec, mat, vec);
	return vec;
}

template <class T>
inline void MulVecMatrix(const _Vector3<T> &vec, const _Matrix<T> &mat, _Vector3<T> &prod)
{
	DoMulVecMat(vec, mat, prod);
}

template <class T>
inline void MulMatScale3X3InPlace(_Matrix<T> &mat, const T &scale)
{
	mat.m00 *= scale;
	mat.m01 *= scale;
	mat.m02 *= scale;

	mat.m10 *= scale;
	mat.m11 *= scale;
	mat.m12 *= scale;

	mat.m20 *= scale;
	mat.m21 *= scale;
	mat.m22 *= scale;
}

template <class T>
inline void MulScaleMat3X3(const T &scale, const _Matrix<T> &mat, _Matrix<T> &prod)
{
	prod = mat;
	MulMatScale3X3InPlace(prod, scale);
}

template <class T>
inline void MulMatScale3X3(const _Matrix<T> &mat, const T &scale, _Matrix<T> &prod)
{
	prod = mat;
	MulMatScale3X3InPlace(prod, scale);
}

template <class T>
inline T TransformVecInPlace(_Vector3<T> &vec, const _Matrix<T> &mat)
{
	return DoTransformVec(vec, mat);
}

template <class T>
inline T TransformVec(const _Vector3<T> &vec, const _Matrix<T> &mat, _Vector3<T> &prod)
{
	prod = vec;
	return TransformVecInPlace(prod, mat);
}

template <class T>
inline void MulVecMat3X3(const _Vector3<T> &vec, const _Matrix<T> &mat, _Vector3<T> &prod)
{
	DoMulVecMat3X3(vec, mat, prod);
}

template <class T>
inline void MulVecMat3X3InPlace(_Vector3<T> &vec, const _Matrix<T> &mat)
{
	DoMulVecMat3X3(vec, mat, vec);
}

template <class T>
inline void DoMulScaleMat(const T &scale, const _Matrix<T> &mat, _Matrix<T> &prod)
{
	for (int i = 0; i < N * N; ++i)
	{
		prod.v[i] = mat.v[i] * scale;
	}
}

inline void DoMulScaleMat(const Float &scale, const _Matrix<Float> &mat,
	_Matrix<Float> &prod)
{
#ifdef NEOX
	if (Align16::m_do_sse)
	{
		MulScaleMatSSE(scale, mat, prod);
		return;
	}
#endif

	DoMulScaleMat<Float>(scale, mat, prod);
}

#ifdef NEOX
inline __declspec(naked) void __stdcall MulScaleMatSSE(const Float &scale,
	const Matrix &mat, Matrix &prod)
{
	Assert(((Byte)&mat & 0xf) == 0);
	Assert(((Byte)&prod & 0xf) == 0);
	_asm
	{
		mov		eax, [esp + 4]
		mov		ecx, [esp + 8]
		mov		edx, [esp + 12]

		movaps	xmm0, [ecx]
		movss	xmm4, [eax]
		movaps	xmm1, [ecx + 10h]
		shufps	xmm4, xmm4, 0
		movaps	xmm2, [ecx + 20h]
		mulps	xmm0, xmm4
		movaps	xmm3, [ecx + 30h]
		mulps	xmm1, xmm4
		movaps	xmm3, [ecx + 30h]
		mulps	xmm2, xmm4
		movaps	[edx], xmm0
		mulps	xmm3, xmm4
		movaps	[edx + 10h], xmm1
		movaps	[edx + 20h], xmm2
		movaps	[edx + 30h], xmm3

		ret		12
	}
}
#endif

template <class T>
inline void DoMulMat(const _Matrix<T> &mat1, const _Matrix<T> &mat2,
	_Matrix<T> &prod)
{
	//TODO(wulf):诡异的逻辑
	//_Matrix<T> &p = (&mat2 == &prod) ? _Matrix<T>() : prod;
	_Matrix<T> t = _Matrix<T>();
	_Matrix<T> &p = (&mat2 == &prod) ? t : prod;

	for (int i = 0; i < N; ++i)
	{
		for (int j = 0; j < N; ++j)
		{
			T sum = 0;
			for (int k = 0; k < N; ++k)
			{
				sum += mat1.m[i][k] * mat2.m[k][j];
			}
			p.m[i][j] = sum;
		}
	}
	prod = p;
}

inline void DoMulMat(const _Matrix<Float> &mat1, const _Matrix<Float> &mat2,
	_Matrix<Float> &prod)
{
#ifdef NEOX
	if (Align16::m_do_sse)
	{
		MulMatSSE(mat1, mat2, prod);
		return;
	}
#endif

	DoMulMat<Float>(mat1, mat2, prod);
}

#ifdef NEOX
inline __declspec(naked) void __stdcall MulMatSSE(const Matrix &mat1,
	const Matrix &mat2, Matrix &prod)
{
	Assert(((Byte)&mat1 & 0xf) == 0);
	Assert(((Byte)&mat2 & 0xf) == 0);
	Assert(((Byte)&prod & 0xf) == 0);
	_asm
	{
		mov		ecx, [esp + 8]
	//	test	cl, 0xf
	//	jz		do_sse			// mat2是16字节对齐才使用SSE计算
	//	xor		eax, eax		// 否则返回false
	//	ret		8

	//do_sse:
		mov		eax, [esp + 4]
		mov		edx, [esp + 0ch]

		movss	xmm0, [eax]			;读入第一行的数据
		movaps	xmm4, [ecx]
		movss	xmm1, [eax + 4]
		shufps	xmm0, xmm0, 0
		movaps	xmm5, [ecx + 10h]
		movss	xmm2, [eax + 8]
		shufps	xmm1, xmm1, 0
		mulps	xmm0, xmm4
		movaps	xmm6, [ecx + 20h]
		mulps	xmm1, xmm5
		movss	xmm3, [eax + 0ch]
		shufps	xmm2, xmm2, 0
		movaps	xmm7, [ecx + 30h]
		shufps	xmm3, xmm3, 0
		mulps	xmm2, xmm6
		addps	xmm1, xmm0
		movss	xmm0, [eax + 10h]	;读入第二行的数据
		mulps	xmm3, xmm7
		shufps	xmm0, xmm0, 0
		addps	xmm2, xmm1
		movss	xmm1, [eax + 14h]
		mulps	xmm0, xmm4
		shufps	xmm1, xmm1, 0
		addps	xmm3, xmm2
		movss	xmm2, [eax + 18h]
		mulps	xmm1, xmm5
		shufps	xmm2, xmm2, 0
		movaps	[edx], xmm3
		movss	xmm3, [eax + 1ch]
		mulps	xmm2, xmm6
		shufps	xmm3, xmm3, 0
		addps	xmm1, xmm0
		movss	xmm0, [eax + 20h]	;读入第三行的数据
		mulps	xmm3, xmm7
		shufps	xmm0, xmm0, 0
		addps	xmm2, xmm1
		movss	xmm1, [eax + 24h]
		mulps	xmm0, xmm4
		shufps	xmm1, xmm1, 0
		addps	xmm3, xmm2
		movss	xmm2, [eax + 28h]
		mulps	xmm1, xmm5
		shufps	xmm2, xmm2, 0
		movaps	[edx + 10h], xmm3
		movss	xmm3, [eax + 2ch]
		mulps	xmm2, xmm6
		shufps	xmm3, xmm3, 0
		addps	xmm1, xmm0
		movss	xmm0, [eax + 30h]	;读入第四行的数据
		mulps	xmm3, xmm7
		shufps	xmm0, xmm0, 0
		addps	xmm2, xmm1
		movss	xmm1, [eax + 34h]
		mulps	xmm0, xmm4
		shufps	xmm1, xmm1, 0
		addps	xmm3, xmm2
		movss	xmm2, [eax + 38h]
		mulps	xmm1, xmm5
		shufps	xmm2, xmm2, 0
		movaps	[edx + 20h], xmm3
		movss	xmm3, [eax + 3ch]
		mulps	xmm2, xmm6
		shufps	xmm3, xmm3, 0
		addps	xmm1, xmm0
		mulps	xmm3, xmm7
		addps	xmm2, xmm1
		addps	xmm3, xmm2
		movaps	[edx + 30h], xmm3

		ret		12
	}
}
#endif

template <class T>
inline bool DoInverseMat(_Matrix<T> &mat, T *determinant)
{
	T work[4][8];
	int row_map[4];

	//Setup [A I]
	for (int i = 0; i < 4; ++i)
	{
		memcpy(work[i], mat.m[i], 4 * sizeof(T));
		memset(work[i] + 4, 0, 4 * sizeof(T));
		work[i][4 + i] = (T)1;
		row_map[i] = i;
	}

	//Use row operations to get to reduced row-echelon form using these rules:
	//1. Multiply or divide a row by a nonzero number.
	//2. Add a multiple of one row to another.
	//3. Interchange two rows.
	for (int row = 0; row < 4; ++row) 
	{
		// Find the row with the largest element in this column.
		T largest = 0;
		int index = -1;

		for (int i = row; i < 4; ++i)
		{
			T test = Abs<T>(work[row_map[i]][row]);
			if (test > largest)
			{
				largest = test;
				index = i;
			}
		}

		// singular matrix
		if (index == -1)
		{
			return false;
		}

		//Swap the rows.
		int temp = row_map[index];
		row_map[index] = row_map[row];
		row_map[row] = temp;

		T *the_row = work[row_map[row]];

		//Divide this row by the element.
		T mul = (T)1 / the_row[row];
		for (int j = row + 1; j < 8; ++j)
		{
			the_row[j] *= mul;
		}

		//Eliminate this element from the other rows using operation 2.
		for (int i = 0; i < 4; ++i)
		{
			if (i == row)
			{
				continue;
			}

			T *scale_row = work[row_map[i]];

			//Multiply this row by -(row * the element).
			mul = -scale_row[row];
			for (int j = row + 1; j < 8; ++j)
			{
				scale_row[j] += the_row[j] * mul;
			}
		}
	}

	//The inverse is on the right side of AX now (the identity is on the left).
	for (int i = 0; i < 4; ++i)
	{
		memcpy(mat.m[i], work[row_map[i]] + 4, 4 * sizeof(T));
	}
	return true;
}

inline bool DoInverseMat(_Matrix<Float> &mat, Float *determinant)
{
#ifdef NEOX
	if (Align16::m_do_sse)
	{
		return InverseMatSSE(mat, determinant);
	}
#endif
	return DoInverseMat<Float>(mat, determinant);
}

#ifdef NEOX
inline __declspec(naked) bool __stdcall InverseMatSSE(Matrix &mat, Float *determinant)
{
	Assert(((Byte)&mat & 0xf) == 0);
	_asm
	{
		mov		eax, [esp + 4]

		push	ebp
		mov		ebp, esp

		and		esp, 0fffffff0h
		sub		esp, 90h

		movaps	xmm2, [esp + 30h]
		movlps	xmm2, [eax]
		movaps	xmm1, [esp + 70h]
		lea		ecx, [eax + 10h]
		movhps	xmm2, [ecx]
		lea		edx, [eax + 20h]
		movlps	xmm1, [edx]
		movaps	xmm0, xmm2
		lea		ecx, [eax + 30h]
		movhps	xmm1, [ecx]
		shufps	xmm0, xmm1, 88h
		shufps	xmm1, xmm2, 0ddh
		lea		edx, [eax + 8]
		movlps	xmm2, [edx]
		movaps	xmm3, xmm2
		movaps	xmm2, [esp + 70h]
		lea		ecx, [eax + 18h]
		movhps	xmm3, [ecx]
		movaps	xmm5, xmm3
		lea		ecx, [eax + 38h]
		add		eax, 28h
		movlps	xmm2, [eax]
		movhps	xmm2, [ecx]
		shufps	xmm5, xmm2, 88h
		shufps	xmm2, xmm3, 0ddh
		movaps	xmm3, xmm5
		mulps	xmm3, xmm2
		shufps	xmm3, xmm3, 0b1h
		movaps	xmm4, xmm1
		mulps	xmm4, xmm3
		movaps	[esp + 50h], xmm4
		movaps	xmm4, xmm3
		shufps	xmm4, xmm3, 4eh
		movaps	xmm6, xmm0
		mulps	xmm6, xmm3
		movaps	xmm3, xmm1
		mulps	xmm3, xmm4
		subps	xmm3, [esp + 50h]
		movaps	xmm7, xmm0
		mulps	xmm7, xmm4
		movaps	xmm4, xmm7
		subps	xmm4, xmm6
		movaps	[esp + 10h], xmm4
		movaps	xmm6, xmm1
		mulps	xmm6, xmm5
		shufps	xmm6, xmm6, 0b1h
		movaps	xmm7, xmm0
		mulps	xmm7, xmm6
		movaps	[esp + 40h], xmm7
		movaps	xmm4, xmm2
		mulps	xmm4, xmm6
		shufps	xmm6, xmm6, 4eh
		movaps	xmm7, xmm2
		mulps	xmm7, xmm6
		movaps	[esp + 60h], xmm7
		movaps	xmm7, xmm0
		mulps	xmm7, xmm6
		movaps	xmm6, xmm7
		subps	xmm6, [esp + 40h]
		movaps	[esp + 40h], xmm6
		movaps	xmm6, xmm1
		shufps	xmm6, xmm1, 4eh
		mulps	xmm6, xmm2
		shufps	xmm6, xmm6, 0b1h
		shufps	xmm5, xmm5, 4eh
		movaps	xmm7, xmm5
		mulps	xmm7, xmm6
		movaps	[esp + 20h], xmm7
		addps	xmm4, xmm3
		subps	xmm4, [esp + 60h]
		movaps	xmm3, [esp + 20h]
		movaps	xmm7, xmm0
		mulps	xmm7, xmm6
		movaps	[esp], xmm7
		shufps	xmm6, xmm6, 4eh
		movaps	xmm7, xmm5
		mulps	xmm7, xmm6
		addps	xmm3, xmm4
		movaps	[esp + 30h], xmm6
		subps	xmm3, xmm7
		movaps	[esp + 50h], xmm3
		movaps	xmm7, xmm2
		movaps	xmm3, xmm0
		mulps	xmm3, [esp + 30h]
		subps	xmm3, [esp]
		movaps	[esp], xmm3
		movaps	xmm3, xmm2
		movaps	xmm6, xmm0
		mulps	xmm6, xmm1
		shufps	xmm6, xmm6, 0b1h
		mulps	xmm3, xmm6
		movaps	xmm4, xmm5
		mulps	xmm4, xmm6
		shufps	xmm6, xmm6, 4eh
		mulps	xmm7, xmm6
		movaps	[esp + 20h], xmm7
		movaps	xmm7, xmm5
		mulps	xmm7, xmm6
		movaps	[esp + 70h], xmm7
		movaps	xmm6, xmm0
		mulps	xmm6, xmm2
		shufps	xmm6, xmm6, 0b1h
		movaps	xmm7, xmm5
		mulps	xmm7, xmm6
		movaps	[esp + 30h], xmm7
		movaps	xmm7, xmm1
		mulps	xmm7, xmm6
		shufps	xmm6, xmm6, 4eh
		movaps	[esp + 60h], xmm7
		movaps	xmm7, xmm5
		mulps	xmm7, xmm6
		movaps	[esp + 80h], xmm7
		movaps	xmm7, xmm1
		mulps	xmm7, xmm6
		movaps	xmm6, [esp]
		shufps	xmm6, [esp], 4eh
		addps	xmm3, xmm6
		movaps	xmm6, xmm3
		movaps	xmm3, [esp + 20h]
		subps	xmm3, xmm6
		movaps	xmm6, xmm3
		movaps	xmm3, [esp + 60h]
		addps	xmm3, xmm6
		subps	xmm3, xmm7
		movaps	[esp], xmm3
		movaps	xmm3, xmm0
		mulps	xmm0, [esp + 50h]
		mulps	xmm3, xmm5
		movaps	xmm5, xmm3
		shufps	xmm5, xmm3, 0b1h
		movaps	xmm3, xmm2
		movaps	xmm6, xmm1
		mulps	xmm3, xmm5
		mulps	xmm6, xmm5
		shufps	xmm5, xmm5, 4eh
		mulps	xmm2, xmm5
		movaps	[esp + 20h], xmm6
		movaps	xmm6, xmm2
		movaps	xmm2, [esp + 10h]
		shufps	xmm2, [esp + 10h], 4eh
		subps	xmm2, [esp + 30h]
		movaps	xmm7, xmm2
		movaps	xmm2, [esp + 80h]
		addps	xmm2, xmm7
		addps	xmm3, xmm2
		movaps	xmm2, [esp + 40h]
		shufps	xmm2, [esp + 40h], 4eh
		subps	xmm4, xmm2
		subps	xmm4, [esp + 70h]
		subps	xmm4, [esp + 20h]
		movaps	xmm2, xmm0
		shufps	xmm2, xmm0, 4eh
		addps	xmm2, xmm0
		movaps	xmm0, xmm2
		shufps	xmm0, xmm2, 0b1h
		mulps	xmm1, xmm5
		addss	xmm0, xmm2
		subps	xmm3, xmm6
		addps	xmm1, xmm4
		xorps	xmm2, xmm2
		xor		eax, eax
		inc		eax
		xor		ecx, ecx
		comiss	xmm0, xmm2
		cmove	ecx, eax
		test	ecx, ecx
		je		next1						;如果存在逆矩阵则转到下一步
		xor		eax, eax					;否则结束计算返回零
		jmp		done
	next1:
		mov		eax, [ebp + 0ch]			;取行列式的地址
		test	eax, eax
		je		next2						;行列式的地址为零跳过下一句
		movss	[eax], xmm0					;输出行列式
	next2:
		mov		eax, mat					;取矩阵的地址
		movaps	[esp + 10h], xmm0
		rcpss	xmm2, xmm0
		movss	[esp + 10h], xmm2
		movaps	xmm2, [esp + 10h]
		movaps	xmm4, xmm2
		mulss	xmm4, xmm2
		mulss	xmm0, xmm4
		movaps	xmm4, xmm0
		movaps	xmm0, xmm2
		addss	xmm0, xmm2
		subss	xmm0, xmm4
		shufps	xmm0, xmm0, 0
		movaps	xmm2, xmm0
		mulps	xmm2, [esp + 50h]
		movaps	[eax], xmm2
		movaps	xmm2, xmm0
		mulps	xmm2, xmm3
		lea		ecx, [eax + 10h]
		movaps	[ecx], xmm2
		movaps	xmm2, xmm0
		mulps	xmm2, [esp]
		lea		ecx, [eax + 20h]
		movaps	[ecx], xmm2
		lea		ecx, [eax + 30h]
		mulps	xmm0, xmm1
		movaps	[ecx], xmm0
		xor		eax, eax
		inc		eax
	done:
		mov		esp, ebp
		pop		ebp
		ret		8
	}
}
#endif

template <class T>
inline void DoMulVec2Mat(_Point2<T> &pos, const _Matrix<T> &mat)
{
	_Point2<T> prod;
	prod.x = pos.x * mat.m00 + pos.y * mat.m10 + mat.m30;
	prod.y = pos.x * mat.m01 + pos.y * mat.m11 + mat.m31;
	pos = prod;
}

template <class T>
inline void DoMulVecMat(const _Vector3<T> &vec, const _Matrix<T> &mat, _Vector3<T> &prod)
{
	_Vector3<T> temp;
	temp.x = vec.x * mat.m00 + vec.y * mat.m10 + vec.z * mat.m20 + mat.m30;
	temp.y = vec.x * mat.m01 + vec.y * mat.m11 + vec.z * mat.m21 + mat.m31;
	temp.z = vec.x * mat.m02 + vec.y * mat.m12 + vec.z * mat.m22 + mat.m32;
	prod = temp;
}

inline void DoMulVecMat(const _Vector3<Float> &vec, const _Matrix<Float> &mat,
	_Vector3<Float> &prod)
{
#ifdef NEOX
	if (Align16::m_do_sse)
	{
		MulVecMatSSE(vec, mat, prod);
		return;
	}
#endif

	DoMulVecMat<Float>(vec, mat, prod);
}

#ifdef NEOX
inline __declspec(naked) void __stdcall MulVecMatSSE(const Vector3 &vec,
	const Matrix &mat, Vector3 &prod)
{
	Assert(((Byte)&mat & 0xf) == 0);
	_asm
	{
		mov		eax, [esp + 4]
		mov		ecx, [esp + 8]

		movaps	xmm0, [ecx]
		movss	xmm4, [eax]
		shufps	xmm4, xmm4, 0

		movaps	xmm1, [ecx + 10h]
		movss	xmm5, [eax + 4]
		mulps	xmm0, xmm4
		shufps	xmm5, xmm5, 0

		movaps	xmm2, [ecx + 20h]
		movss	xmm6, [eax + 8]
		mulps	xmm1, xmm5
		shufps	xmm6, xmm6, 0

		movaps	xmm3, [ecx + 30h]
		mov		eax, [esp + 12]

		addps	xmm0, xmm1
		mulps	xmm2, xmm6
		addps	xmm0, xmm3
		addps	xmm0, xmm2

		movhlps	xmm4, xmm0
		movlps	[eax], xmm0
		movss	[eax + 8], xmm4

		ret		12
	}
}
#endif

template <class T>
inline void DoMulVecMat3X3(const _Vector3<T> &vec, const _Matrix<T> &mat, _Vector3<T> &prod)
{
	_Vector3<T> temp;
	temp.x = vec.x * mat.m00 + vec.y * mat.m10 + vec.z * mat.m20;
	temp.y = vec.x * mat.m01 + vec.y * mat.m11 + vec.z * mat.m21;
	temp.z = vec.x * mat.m02 + vec.y * mat.m12 + vec.z * mat.m22;
	prod = temp;
}

inline void DoMulVecMat3X3(const _Vector3<Float> &vec, const _Matrix<Float> &mat,
	_Vector3<Float> &prod)
{
#ifdef NEOX
	if (Align16::m_do_sse)
	{
		MulVecMat3X3SSE(vec, mat, prod);
		return;
	}
#endif

	DoMulVecMat3X3<Float>(vec, mat, prod);
}

#ifdef NEOX
inline __declspec(naked) void __stdcall MulVecMat3X3SSE(const Vector3 &vec,
	const Matrix &mat, Vector3 &prod)
{
	Assert(((Byte)&mat & 0xf) == 0);
	_asm
	{
		mov		eax, [esp + 4]
		mov		ecx, [esp + 8]

		movaps	xmm0, [ecx]
		movss	xmm4, [eax]
		shufps	xmm4, xmm4, 0

		movaps	xmm1, [ecx + 10h]
		movss	xmm5, [eax + 4]
		mulps	xmm0, xmm4
		shufps	xmm5, xmm5, 0

		movaps	xmm2, [ecx + 20h]
		movss	xmm6, [eax + 8]
		mulps	xmm1, xmm5
		shufps	xmm6, xmm6, 0

		//movaps	xmm3, [ecx + 30h]
		mov		eax, [esp + 12]

		addps	xmm0, xmm1
		mulps	xmm2, xmm6
		//addps	xmm0, xmm3
		addps	xmm0, xmm2

		movhlps	xmm4, xmm0
		movlps	[eax], xmm0
		movss	[eax + 8], xmm4

		ret		12
	}
}
#endif

template <class T>
inline T DoTransformVec(_Vector3<T> &vec, const _Matrix<T> &mat)
{
	_Vector3<T> prod;
	T reci_w =
		(T)1 / (vec.x * mat.m03 + vec.y * mat.m13 + vec.z * mat.m23 + mat.m33);
	prod = vec;
	prod *= mat;
	prod.x *= reci_w;
	prod.y *= reci_w;
	prod.z *= reci_w;
	vec = prod;
	return reci_w;
}

inline Float DoTransformVec(_Vector3<Float> &vec, const _Matrix<Float> &mat)
{
#ifdef NEOX
	Float reci_w;
	if (Align16::m_do_sse)
	{
		TransformVecSSE(vec, mat, reci_w);
		return reci_w;
	}
#endif

	return DoTransformVec<Float>(vec, mat);
}

#ifdef NEOX
inline __declspec(naked) void __stdcall TransformVecSSE(Vector3 &vec,
	const Matrix &mat, Float &reci_w)
{
	Assert(((Byte)&mat & 0xf) == 0);
	_asm
	{
		mov		eax, [esp + 4]
		mov		ecx, [esp + 8]

		movss	xmm4, [eax]
		movss	xmm5, [eax + 4]
		movss	xmm6, [eax + 8]

		shufps	xmm4, xmm4, 0
		movaps	xmm0, [ecx]
		shufps	xmm5, xmm5, 0
		movaps	xmm1, [ecx + 10h]
		shufps	xmm6, xmm6, 0
		movaps	xmm2, [ecx + 20h]

		mulps	xmm0, xmm4
		mulps	xmm1, xmm5
		mulps	xmm2, xmm6
		movaps	xmm3, [ecx + 30h]

		addps	xmm0, xmm1
		addps	xmm2, xmm3
		addps	xmm0, xmm2

		movaps	xmm4, xmm0
		shufps	xmm4, xmm4, 3

		mov		dword ptr[esp + 0ch], 3f800000h
		movss	xmm5, [esp + 0ch]
		divss	xmm5, xmm4
/*
		rcpss	xmm7, xmm4

		// rcpss指令计算的是近似值，需要通过牛顿迭代得到较精确值

		movaps	xmm5, xmm7
		mulss	xmm5, xmm7
		mulss	xmm4, xmm5

		movaps	xmm5, xmm7
		addss	xmm5, xmm7
		subss	xmm5, xmm4
*/
		shufps	xmm5, xmm5, 0

		mulps	xmm0, xmm5
		movss	[esp + 0ch], xmm5

		movhlps	xmm6, xmm0
		movlps	[eax], xmm0
		movss	[eax + 8], xmm6
		ret		0ch
	}
}
#endif

template <class T>
inline void DoAddMatScaled(_Matrix<T> &dest, const _Matrix<T> &mat,
	const T &scale)
{
	for (int i = 0; i < N * N; ++i)
	{
		dest.v[i] += mat.v[i] * scale;
	}
}

inline void DoAddMatScaled(_Matrix<Float> &dest, const _Matrix<Float> &mat,
	const Float &scale)
{
#ifdef NEOX
	if (Align16::m_do_sse)
	{
		AddMatScaledSSE(dest, mat, scale);
		return;
	}
#endif

	DoAddMatScaled<Float>(dest, mat, scale);
}

#ifdef NEOX
inline __declspec(naked) void __stdcall AddMatScaledSSE(Matrix &dest,
	const Matrix &mat, const Float &scale)
{
	Assert(((Byte)&dest & 0xf) == 0);
	Assert(((Byte)&mat & 0xf) == 0);
	_asm
	{
		mov		edx, [esp + 4]
		mov		ecx, [esp + 8]
		mov		eax, [esp + 12]

		movaps	xmm0, [ecx]
		movss	xmm4, [eax]
		movaps	xmm1, [ecx + 10h]
		shufps	xmm4, xmm4, 0
		movaps	xmm2, [ecx + 20h]
		mulps	xmm0, xmm4
		movaps	xmm3, [ecx + 30h]
		mulps	xmm1, xmm4
		movaps	xmm3, [ecx + 30h]
		mulps	xmm2, xmm4
		addps	xmm0, [edx]
		movaps	[edx], xmm0
		mulps	xmm3, xmm4
		addps	xmm1, [edx + 10h]
		movaps	[edx + 10h], xmm1
		addps	xmm2, [edx + 20h]
		movaps	[edx + 20h], xmm2
		addps	xmm3, [edx + 30h]
		movaps	[edx + 30h], xmm3

		ret		12
	}
}
#endif

} // namespace math3d


template <class T>
void FromString(math3d::_Matrix<T> &value, char *buf)
{
	math3d::_Matrix<T> result;

	for (int i = 0; i < 15; ++i)
	{
		char *p = strchr(buf, ',');
		if (p == 0)
		{
			return;
		}

		*p = '\0';
		FromString(result.v[i], buf);
		buf = p + 1;
	}
	FromString(result.v[15], buf);

	value = result;
}

template <class T>
void ToString(const math3d::_Matrix<T> &value, char *buf)
{
	char data_buf[16][256];

	for (int i = 0; i < 16; ++i)
	{
		ToString(value.v[i], data_buf[i]);
	}

	sprintf(buf, "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s", 
		data_buf[0], data_buf[1], data_buf[2], data_buf[3],
		data_buf[4], data_buf[5], data_buf[6], data_buf[7],
		data_buf[8], data_buf[9], data_buf[10], data_buf[11],
		data_buf[12], data_buf[13], data_buf[14], data_buf[15]);
}

} // namespace neox


#endif // __MATRIX_H__
