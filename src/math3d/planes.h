#ifndef __PLANES_H__
#define __PLANES_H__


namespace neox	
{
namespace math3d
{

enum
{
	LINE_INTERSECT_EVERYWHERE = 0,
	LINE_INTERSECT_NOWHERE = 1,
	LINE_INTERSECT_SOMEWHERE = 2
};

template <class T>
struct _Plane
{
	_Vector3<T>	normal;		// 单位法向量
	T dist;					// 原点到平面的负距离

	_Plane()
	{}

	// 参数
	// n	单位法向量
	// d	原点到平面的负距离
	_Plane(const _Vector3<T> &n, const T &d):
		normal(n), dist(d)
	{}

	// 参数
	// nx, ny, nz	单位法向量的三个分量
	// d			原点到平面的负距离
	_Plane(const T &nx, const T &ny, const T &nz, const T &d)
	{
		Set(nx, ny, nz, d);
	}

	// 参数
	// n	单位法向量
	// p	平面上一点
	_Plane(const _Vector3<T> &n, const _Vector3<T> &p)
	{
		Set(n, p);
	}

	// 参数
	// p0, p1, p2	平面上三个点的坐标
	_Plane(const _Vector3<T> &p0, const _Vector3<T> &p1, const _Vector3<T> &p2)
	{
		Set(p0, p1, p2);
	}

	// 参数
	// nx, ny, nz	单位法向量的三个分量
	// d			原点到平面的负距离
	void Set(const T &nx, const T &ny, const T &nz, const T &d)
	{
		normal.x = nx;
		normal.y = ny;
		normal.z = nz;
		dist = d;
	}

	// 参数
	// n	单位法向量
	// p	平面上一点
	void Set(const _Vector3<T> &n, const _Vector3<T> &p)
	{
		normal = n;
		dist = n.Dot(p);
	}

	// 参数
	// p0, p1, p2	平面上三个点的坐标
	bool Set(const _Vector3<T> &p0, const _Vector3<T> &p1, const _Vector3<T> &p2)
	{
		_Vector3<T> v01(p1), v12(p2), v20(p0);
		v01 -= p0;
		v12 -= p1;
		v20 -= p2;
		T l_sqr01 = v01.LengthSqr();
		T l_sqr12 = v12.LengthSqr();
		T l_sqr20 = v20.LengthSqr();

		_Vector3<T> n;
		const _Vector3<T> *p;
		T prod;
		if (l_sqr01 < l_sqr20 && l_sqr12 < l_sqr20)
		{
			v01.Cross(v12, n);
			prod = l_sqr01 * l_sqr12;
			p = &p1;
		}
		else if (l_sqr01 < l_sqr12)
		{
			v20.Cross(v01, n);
			prod = l_sqr20 * l_sqr01;
			p = &p0;
		}
		else
		{
			v12.Cross(v20, n);
			prod = l_sqr12 * l_sqr20;
			p = &p2;
		}

		T n_len_sqr = n.LengthSqr();
		if (n_len_sqr <= prod * EPSILON * EPSILON)
		{
			return false;
		}
		n /= ::sqrt(n_len_sqr);
		Set(n, *p);
		return true;
	}

	// 任取平面上三个不同的点
	// 参数
	// p0, p1, p2	平面上三个点的坐标
	void GetPoints(_Vector3<T> &p0, _Vector3<T> &p1, _Vector3<T> &p2) const
	{
		p0 = normal;
		p0 *= dist;

		Vector3 n_abs(normal), temp;
		n_abs.Absolutize();
		temp.Set(1.0f, 0.0f, 0.0f);
		Float min = n_abs.x;
		if (min > n_abs.y)
		{
			temp.Set(0.0f, 1.0f, 0.0f);
			min = n_abs.y;
		}
		if (min > n_abs.z)
		{
			temp.Set(0.0f, 0.0f, 1.0f);
		}

		temp.Cross(normal, p1);
		normal.Cross(p1, p2);
		p1 += p0;
		p2 += p0;
	}

	// 参数
	// p	空间一点的坐标
	T DistanceTo(const _Vector3<T> &p) const 
	{
		return normal.Dot(p) - dist;
	}

	// 仅使方向向量反向
	const _Plane operator -()
	{
		return _Plane(-normal, -dist);
	}

	bool operator ==(const _Plane &plane) const
	{
		return IsEqual(plane);
	}

	bool operator !=(const _Plane &plane) const
	{
		return !(*this == plane);
	}

	_Plane& operator =(const _Plane &plane)
	{
		normal = plane.normal;
		dist = plane.dist;
		return *this;
	}

	bool IsEqual(const _Plane &plane, const T &eps = EPSILON) const
	{
		return (normal.IsEqual(plane.normal, eps) &&
			Abs(dist - plane.dist) < eps);
	}

	void ProjectPoint(_Vector3<T> &dest, const _Vector3<T> &src) const
	{
		_Vector3<T> temp(normal);
		temp *= DistanceTo(src);
		dest = src;
		dest -= temp;
	}
};

} // namespace math3d
} // namespace neox


#endif // __PLANES_H__
