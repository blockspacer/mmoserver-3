#pragma once

#ifndef __ROTATION_H__
#define __ROTATION_H__

#ifndef __MATH_H__
#include <math.h>
#define __MATH_H__
#endif
#include <stdio.h>

namespace neox
{
namespace math3d
{

// 旋转方向描述类，实现四元数的各种计算，多用于3D空间
// 中物体的平滑旋转计算，两个旋转量之间的插值最常用

template <class T>
struct _Rotation
{
	union
	{
		T q[4];
		struct
		{
			T x, y, z, w;
		};
	};

	_Rotation()
	{}

	_Rotation(const T &_x, const T &_y, const T &_z, const T &_w):
		x(_x), y(_y), z(_z), w(_w)
	{}

	_Rotation(const _Vector3<T> &axis, const T &angle)
	{
		// 约束：axis必须被归一化
		T half_angle = (T)(0.5 * angle);
		T sin_value = sin(half_angle);
		
		x = axis.x * sin_value;
		y = axis.y * sin_value;
		z = axis.z * sin_value;
		w = cos(half_angle);
	}

	void SetIdentity()
	{
		Set(0, 0, 0, 1);
	}

	void Init(T _x = 0, T _y = 0, T _z = 0, T _w = 0)
	{
		Set(_x, _y, _z, _w);
	}

	void Set(T _x, T _y, T _z, T _w)
	{
		x = _x;
		y = _y;
		z = _z;
		w = _w;
	}

	void GetAxisAngle(_Vector3<T> &axis, T &angle)
	{
		// 约束：四元数必须被归一化
		T half_angle = (T)acos(w);
		angle = half_angle * 2;
		T sin_value = (T)sin(half_angle);
		axis.Set(x / sin_value, y / sin_value, z / sin_value);
	}

	bool operator ==(const _Rotation &rot) const
	{
		return IsEqual(rot);
	}

	bool operator !=(const _Rotation &rot) const
	{
		return !(*this == rot);
	}

	bool IsEqual(const _Rotation<T> &rot, const T &eps = EPSILON) const
	{
		T diff = x - rot.x;
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		diff = y - rot.y;
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		diff = z - rot.z;
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		diff = w - rot.w;
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		return true;
	}

	_Rotation<T>& operator -=(const _Rotation<T> &rot)
	{
		for (int i = 0; i < 4; ++i)
		{
			q[i] -= rot.q[i];
		}
		return *this;
	}
	
	void Negative()
	{
		for (int i = 0; i < 4; ++i)
		{
			q[i] = -q[i];
		}
	}

	_Rotation& operator *=(const _Rotation &b)
	{
		// [s1*s2 - v1*v2, s1*v2 + s2*v1 + v1.Cross(v2)]
		_Rotation a = *this;
		x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y;
		y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x;
		z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w;
		w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z;
		return *this;
	}

	void Conjugate()
	{
		x = -x;
		y = -y;
		z = -z;
	}

	void Normalize()
	{
		T len_reci = (T)(1.0 / Length());
		w *= len_reci;
		x *= len_reci;
		y *= len_reci;
		z *= len_reci;
	}
	
	T SqrLength() const
	{
		return Dot(*this);
	}
	
	T Length() const
	{
		return sqrt(SqrLength());
	}
	
	T Dot(const _Rotation<T> &rot) const
	{
		T result = 0;
		
		for (int i = 0; i < 4; ++i)
		{
			result += q[i] * rot.q[i];
		}
		return result;
	}

	bool IsIdentity() const
	{
		return (x == 0.0f && y == 0.0f && z == 0.0f && w == 1.0f);
	}

	void Intrp(const _Rotation<T> &q1, const _Rotation<T> &q2, const T &t)
	{
		_Rotation<T> rot_q2;
		T omega, cos_om, sin_om_reci;

		cos_om = q1.Dot(q2);
		rot_q2 = q2;

		// 调整正负
		if (cos_om < 0.0)
		{
			cos_om = -cos_om;
			rot_q2.Negative();
		}

		// 计算插值运算的系数
		T k0, k1;
		if (cos_om > 1 - EPSILON) 
		{ 
			// q1和q2很接近时做线性插值
			k0 = (T)(1.0 - t);
			k1 = t;
		}
		else
		{ 
			// 四元数插值
			omega = acos(cos_om);
			sin_om_reci = (T)(1.0 / sin(omega));
			k0 = (T)(sin((1.0 - t) * omega) * sin_om_reci);
			k1 = (T)(sin(t * omega) * sin_om_reci);
		}

		// 生成结果
		for (int i = 0; i < 4; ++i)
		{
			q[i] = k0 * q1.q[i] + k1 * rot_q2.q[i];
		}
	}

	void RotateVector(_Vector3<T> &vec_dest, const _Vector3<T> &vec_src) const
	{
		_Rotation<T> prod;				
		const _Rotation<T> &q = *this; 
		const _Vector3<T> &v = vec_src;

		// evaluate quat * vector
		// bw == 0.0f
		prod.x = q.w * v.x/*+ ax * bw*/+ q.y * v.z - q.z * v.y;
		prod.y = q.w * v.y - q.x * v.z/*+ ay * bw*/+ q.z * v.x;
		prod.z = q.w * v.z + q.x * v.y - q.y * v.x/*+ az * bw*/;
		prod.w =/*aw * bw*/- q.x * v.x - q.y * v.y - q.z * v.z;

		_Rotation<T> q_(*this);
		q_.Conjugate(); // conjugate

		// evaluate vector * conj
		vec_dest.x = prod.w * q_.x + prod.x * q_.w + prod.y * q_.z - prod.z * q_.y;
		vec_dest.y = prod.w * q_.y - prod.x * q_.z + prod.y * q_.w + prod.z * q_.x;
		vec_dest.z = prod.w * q_.z + prod.x * q_.y - prod.y * q_.x + prod.z * q_.w;
	}

	void GetForward(_Vector3<T> &vec) const
	{
		vec.x = (T)(2.0 * (x * z + w * y));
		vec.y = (T)(2.0 * (y * z - w * x));
		vec.z = (T)(1.0 - 2.0 * (x * x + y * y));
	}

	void GetUp(_Vector3<T> &vec) const
	{
		vec.x = (T)(2.0 * (x * y - w * z));
		vec.y = (T)(1.0 - 2.0 * (x * x + z * z));
		vec.z = (T)(2.0 * (y * z + w * x));
	}

	void GetRight(_Vector3<T> &vec) const
	{
		vec.x = (T)(1.0 - 2.0 * (y * y + z * z));
		vec.y = (T)(2.0 * (x * y + w * z));
		vec.z = (T)(2.0 * (x * z - w * y));
	}
};

typedef _Rotation<Float> Rotation;

} // namespace math3d

template <class T>
void FromString(math3d::_Rotation<T> &value, char *buf)
{
	math3d::_Rotation<T> result;

	char *p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	FromString(result.x, buf);

	buf = p + 1;
	p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	FromString(result.y, buf);

	buf = p + 1;
	p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	FromString(result.z, buf);

	FromString(result.w, p + 1);
	value = result;
}

template <class T>
void ToString(const math3d::_Rotation<T> &value, char *buf)
{
	char local_buf[4][256];

	for (int i = 0; i < 4; ++i)
	{
		ToString(value.q[i], local_buf[i]);
	}

	sprintf(buf, "%s,%s,%s,%s", local_buf[0], local_buf[1], local_buf[2], local_buf[3]);
}

} // namespace neox


#endif // __ROTATION_H__
