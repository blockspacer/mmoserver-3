#ifndef __VECTORS_H__
#define __VECTORS_H__

#include <math.h>
#include <string.h>
#include <stdio.h>
#include "types.h"

#include "matrix.h"

namespace neox
{
namespace math3d
{

inline Float InvSqrtFast(Float number)
{
	long i;
	Float x2, y;
	const Float threehalfs = 1.5f;

	x2 = number * 0.5f;
	y = number;
	i = *(long*)&y;  // evil floating point bit level hacking
	i = 0x5f3759df - (i >> 1); // what the fuck?
	y = *(Float*)&i;
	y = y * (threehalfs - (x2 * y * y)); // 1st iteration
	// y = y * (threehalfs - (x2 * y * y)); // 2nd iteration, this can be removed
	return y;
}


template <class T>
struct _Vector3
{
	union
	{
		T vec[3];
		struct
		{
			T x, y, z;
		};
	};

	_Vector3()
	{}

	_Vector3(const T &val): 
		x(val), y(val), z(val)
	{}

	_Vector3(const T &_x, const T &_y, const T &_z): 
		x(_x), y(_y), z(_z)
	{}

	void Init(const T &_x = 0, const T &_y = 0, const T &_z = 0)
	{
		Set(_x, _y, _z);
	}

	void Set(const T &_x, const T &_y, const T &_z)
	{
		x = _x;
		y = _y;
		z = _z;
	}
	
	T Dot(const _Vector3 &o_vec) const
	{
		return x * o_vec.x + y * o_vec.y + z * o_vec.z;
	}
	
	T LengthSqr() const
	{
		return Dot(*this);
	}
	
	T Length() const
	{
		return (T)sqrt(LengthSqr());
	}
	
	const _Vector3& Normalize(const T &scale = 1)
	{
		T len = Length();
#ifdef NEOX
		Assert(len != 0);
#endif
		*this *= (scale / len);
		return *this;
	}

	const _Vector3& NormFast(const T &scale = 1)
	{
		*this *= (scale / LengthFast());
		return *this;
	}

	const _Vector3& NormFast2(const T &scale = 1)
	{
		*this *= (InvSqrtFast(LengthSqr()) * scale);
		return *this;
	}

	//bool IsEqual(const _Vector3 &o_vec, const T &eps = EPSILON) const
	//{
	//	_Vector3 d = *this - o_vec;
	//	return d.LengthSqr() <= eps * eps;
	//}

	bool IsEqual(const _Vector3 &o_vec, const T &eps = EPSILON) const
	{
		T diff = x - o_vec.x;
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		diff = y - o_vec.y;
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		diff = z - o_vec.z;
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		return true;
	}

	void Cross(const _Vector3 &o_vec, _Vector3 &prod) const
	{
		prod.Set(y * o_vec.z - z * o_vec.y, z * o_vec.x - x * o_vec.z, x * o_vec.y - y * o_vec.x);
	}

	bool EqualXYZ(const T &eps = EPSILON) const
	{
		return Abs(x - y) < eps && Abs(y - z) < eps;
	}
	
	void Absolutize()
	{
		Set(Abs(x), Abs(y), Abs(z));
	}
	
	void Intrp(const _Vector3 &vec0, const _Vector3 &vec1, const T &u)
	{
		x = vec0.x + (vec1.x - vec0.x) * u;
		y = vec0.y + (vec1.y - vec0.y) * u;
		z = vec0.z + (vec1.z - vec0.z) * u;
	}

	bool IsZero() const
	{
		static const _Vector3 ZERO_VEC((T)0);
		return *this == ZERO_VEC;
	}

	T& operator [](int i)
	{
		return vec[i];
	}
	
	const T& operator [](int i) const
	{
		return vec[i];
	}

	bool operator ==(const _Vector3 &o_vec) const
	{
		return IsEqual(o_vec);
	}

	bool operator !=(const _Vector3 &o_vec) const
	{
		return !(o_vec == *this);
	}

	_Vector3 operator -() const
	{
		return _Vector3(-x, -y, -z);
	}

	_Vector3& operator =(const _Vector3 &o_vec)
	{
		x = o_vec.x;
		y = o_vec.y;
		z = o_vec.z;
		return *this;
	}

	_Vector3& operator +=(const _Vector3 &o_vec) 
	{
		x += o_vec.x;
		y += o_vec.y;
		z += o_vec.z;
		return *this;
	} 

	_Vector3& operator -=(const _Vector3 &o_vec) 
	{
		x -= o_vec.x;
		y -= o_vec.y;
		z -= o_vec.z;
		return *this;
	}

	_Vector3& operator *=(const _Vector3 &o_vec) 
	{
		x *= o_vec.x;
		y *= o_vec.y;
		z *= o_vec.z;
		return *this;
	}

	_Vector3& operator /=(const _Vector3 &o_vec) 
	{
		x /= o_vec.x;
		y /= o_vec.y;
		z /= o_vec.z;
		return *this;
	}

	_Vector3 operator +(const _Vector3 &o_vec) const
	{
		return _Vector3(x + o_vec.x, y + o_vec.y, z + o_vec.z);
	}

	_Vector3 operator -(const _Vector3 &o_vec) const
	{
		return _Vector3(x - o_vec.x, y - o_vec.y, z - o_vec.z);
	}

	_Vector3 operator *(const _Vector3 &o_vec) const
	{
		return _Vector3(x * o_vec.x, y * o_vec.y, z * o_vec.z);
	}

	_Vector3 operator /(const _Vector3 &o_vec) const
	{
		return _Vector3(x / o_vec.x, y / o_vec.y, z / o_vec.z);
	}

	_Vector3& operator *=(const T &scale)
	{
		x *= scale;
		y *= scale;
		z *= scale;
		return *this;
	}

	_Vector3& operator /=(const T &scale)
	{
		T reci = 1 / scale;
		x *= reci;
		y *= reci;
		z *= reci;
		return *this;
	}

	_Vector3 operator *(const T &scale) const
	{
		return _Vector3(x * scale, y * scale, z * scale);
	}

	_Vector3 operator /(const T &scale) const
	{
		const T r = 1 / scale;
		return _Vector3(x * r, y * r, z * r);
	}
	
	_Vector3& operator +=(const T &scale)
	{
		x += scale;
		y += scale;
		z += scale;
		return *this;
	}

	_Vector3& operator -=(const T &scale)
	{
		x -= scale;
		y -= scale;
		z -= scale;
		return *this;
	}

	T Distance(const _Vector3 &o_vec) const
	{
		return (*this - o_vec).Length();
	}

	T DistanceSqr(const _Vector3 &o_vec) const
	{
		return (*this - o_vec).LengthSqr();
	}

	T LengthFast() const
	{
		T min, mid, max;
		T temp;

		max = Abs(x);
		mid = Abs(y);
		min = Abs(z);

		if (max < mid)
		{
			temp = max;
			max = mid;
			mid = temp;
		}

		if (max < min)
		{
			temp = max;
			max = min;
			min = temp;
		}

		return max + ((mid + min) * 0.25f);
	}

	_Vector3& AddScaled(const _Vector3 &vec1, const _Vector3 &vec2, const T &scale)
	{
		x = vec1.x + vec2.x * scale;
		y = vec1.y + vec2.y * scale;
		z = vec1.z + vec2.z * scale;
		return *this;
	}

	_Vector3& MergeforMin(const _Vector3 &other)
	{
		if (x > other.x)
		{
			x = other.x;
		}
		if (y > other.y)
		{
			y = other.y;
		}
		if (z > other.z)
		{
			z = other.z;
		}

		return *this;
	}

	_Vector3& MergeforMax(const _Vector3 &other)
	{
		if (x < other.x)
		{
			x = other.x;
		}
		if (y < other.y)
		{
			y = other.y;
		}
		if (z < other.z)
		{
			z = other.z;
		}

		return *this;
	}

	T Min() const
	{
		T min = x;
		if (min > y)
		{
			min = y;
		}
		if (min > z)
		{
			min = z;
		}
		return min;
	}

	T Max() const
	{
		T max = x;
		if (max < y)
		{
			max = y;
		}
		if (max < z)
		{
			max = z;
		}
		return max;
	}

	void ToString(char *buf)
	{
		sprintf(buf, "%f,%f,%f", x, y, z);
	}
};

//typedef _Vector3<Float> Vector3;

typedef Vector3 Point3;
typedef Vector3 Size3;

template <class T>
inline T Abs(_Vector3<T> vec)
{
	return vec.Length();
}

// 求两个向量夹角的余弦
template <class T>
inline T Cos2Vec(const _Vector3<T> &a, const _Vector3<T> &b)
{
	return a.Dot(b) / ::sqrt(a.LengthSqr() * b.LengthSqr());
}

// 求两个向量夹角正弦的平方
template <class T>
inline T Sin2VecSqr(const _Vector3<T> &a, const _Vector3<T> &b)
{
	Vector3 cross;
	a.Cross(b, cross);
	return cross.LengthSqr() / (a.LengthSqr() * b.LengthSqr());
}

// 求两个向量夹角的正弦
template <class T>
inline T Sin2Vec(const _Vector3<T> &a, const _Vector3<T> &b)
{
	return ::sqrt(Sin2VecSqr(a, b));
}

enum
{
	INSIDE = 0,
	OUTSIDE_EDGE_AB = 0x1,
	OUTSIDE_EDGE_BC = 0x2,
	OUTSIDE_EDGE_CA = 0x4,
	OUTSIDE_EDGE_CD = 0x8,
	OUTSIDE_EDGE_DA = 0x10,
};

template <class T>
inline bool PointInTriangle(const _Vector3<T> &point, const _Vector3<T> &a,
	const _Vector3<T> &b, const _Vector3<T> &c, int *area = NULL)
{
	// 判断点P是否在三角形ABC内
	// 约束：点P是平面ABC上一点

	_Vector3<T> v0(a), v1(b), v2(c);
	v0 -= point;					// 向量PA
	v1 -= point;					// 向量PB
	v2 -= point;					// 向量PC

	if (area == NULL)
	{
		if (v0.x < -EPSILON && v1.x < -EPSILON && v2.x < -EPSILON)
		{
			return false;
		}
		if (v0.y < -EPSILON && v1.y < -EPSILON && v2.y < -EPSILON)
		{
			return false;
		}
		if (v0.z < -EPSILON && v1.z < -EPSILON && v2.z < -EPSILON)
		{
			return false;
		}
		if (v0.x > EPSILON && v1.x > EPSILON && v2.x > EPSILON)
		{
			return false;
		}
		if (v0.y > EPSILON && v1.y > EPSILON && v2.y > EPSILON)
		{
			return false;
		}
		if (v0.z > EPSILON && v1.z > EPSILON && v2.z > EPSILON)
		{
			return false;
		}
	}

	_Vector3<T> n01, n12, n20;
	v0.Cross(v1, n01);				// n01 = PA×PB
	v1.Cross(v2, n12);				// n12 = PB×PC
	v2.Cross(v0, n20);				// n20 = PC×PA

	if (area != NULL)
	{
		_Vector3<T> e20(a), e21(b), n;
		e20 -= c;
		e21 -= c;
		e20.Cross(e21, n);			// ABC平面的法线

		*area = 0;
		if (n01.Dot(n) < 0)
		{
			*area |= OUTSIDE_EDGE_AB;
		}
		if (n12.Dot(n) < 0)
		{
			*area |= OUTSIDE_EDGE_BC;
		}
		if (n20.Dot(n) < 0)
		{
			*area |= OUTSIDE_EDGE_CA;
		}
		return *area == INSIDE;
	}

	// 如果三法线同方向说明P在三角形ABC内
	if (n01.Dot(n12) >= 0 && n01.Dot(n20) >= 0)
	{
		return true;
	}
	return false;
}

/*
A +-------+ B
  |       |
  |       |
  |       |
  |       |
D +-------+ C
*/

template <class T>
inline bool PointInQuadrangle(const _Vector3<T> &point, const _Vector3<T> &a,
	const _Vector3<T> &b, const _Vector3<T> &c, const _Vector3<T> &d, int *area = NULL)
{
	// 判断点P是否在四边形ABCD内
	// 约束：ABCD是共面凸四边形，P在其平面上

	_Vector3<T> v0(a), v1(b), v2(c), v3(d);
	v0 -= point;					// 向量PA
	v1 -= point;					// 向量PB
	v2 -= point;					// 向量PC
	v3 -= point;					// 向量PD

	const Float EPS = EPSILON * 10.0f;

	if (area == NULL)
	{
		if (v0.x < -EPS && v1.x < -EPS && v2.x < -EPS && v3.x < -EPS)
		{
			return false;
		}
		if (v0.y < -EPS && v1.y < -EPS && v2.y < -EPS && v3.y < -EPS)
		{
			return false;
		}
		if (v0.z < -EPS && v1.z < -EPS && v2.z < -EPS && v3.z < -EPS)
		{
			return false;
		}
		if (v0.x > EPS && v1.x > EPS && v2.x > EPS && v3.x > EPS)
		{
			return false;
		}
		if (v0.y > EPS && v1.y > EPS && v2.y > EPS && v3.y > EPS)
		{
			return false;
		}
		if (v0.z > EPS && v1.z > EPS && v2.z > EPS && v3.z > EPS)
		{
			return false;
		}
	}

	Vector3 n01, n12, n23, n30;		// ABCD平面的法线
	v0.Cross(v1, n01);				// n01 = PA×PB
	v1.Cross(v2, n12);				// n12 = PB×PC
	v2.Cross(v3, n23);				// n23 = PC×PD
	v3.Cross(v0, n30);				// n30 = PD×PA

	if (area != NULL)
	{
		Vector3 e30(v0), e31(v1), n;
		e30 -= v3;
		e31 -= v3;
		e30.Cross(e31, n);

		*area = 0;
		if (n01.Dot(n) < 0)
		{
			*area |= OUTSIDE_EDGE_AB;
		}
		if (n12.Dot(n) < 0)
		{
			*area |= OUTSIDE_EDGE_BC;
		}
		if (n23.Dot(n) < 0)
		{
			*area |= OUTSIDE_EDGE_CD;
		}
		if (n30.Dot(n) < 0)
		{
			*area |= OUTSIDE_EDGE_DA;
		}
		return *area == INSIDE;
	}

	// 如果四法线同方向说明P在四边形ABCD内
	if (n01.Dot(n12) >= 0 && n01.Dot(n23) >= 0 && n01.Dot(n30) >= 0)
	{
		return true;
	}
	return false;
}

} // namespace math3d

template <class T>
void FromString(math3d::_Vector3<T> &value, char *buf)
{
	math3d::_Vector3<T> result;

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

	FromString(result.z, p + 1);
	value = result;
}

template <class T>
void ToString(const math3d::_Vector3<T> &value, char *buf)
{
	char local_buf[3][256];

	for (int i = 0; i < 3; ++i)
	{
		ToString(value.vec[i], local_buf[i]);
	}

	sprintf(buf, "%s,%s,%s", local_buf[0], local_buf[1], local_buf[2]);
}

} // namespace neox

#endif // __VECTORS_H__
