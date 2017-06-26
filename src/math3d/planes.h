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
	_Vector3<T>	normal;		// ��λ������
	T dist;					// ԭ�㵽ƽ��ĸ�����

	_Plane()
	{}

	// ����
	// n	��λ������
	// d	ԭ�㵽ƽ��ĸ�����
	_Plane(const _Vector3<T> &n, const T &d):
		normal(n), dist(d)
	{}

	// ����
	// nx, ny, nz	��λ����������������
	// d			ԭ�㵽ƽ��ĸ�����
	_Plane(const T &nx, const T &ny, const T &nz, const T &d)
	{
		Set(nx, ny, nz, d);
	}

	// ����
	// n	��λ������
	// p	ƽ����һ��
	_Plane(const _Vector3<T> &n, const _Vector3<T> &p)
	{
		Set(n, p);
	}

	// ����
	// p0, p1, p2	ƽ���������������
	_Plane(const _Vector3<T> &p0, const _Vector3<T> &p1, const _Vector3<T> &p2)
	{
		Set(p0, p1, p2);
	}

	// ����
	// nx, ny, nz	��λ����������������
	// d			ԭ�㵽ƽ��ĸ�����
	void Set(const T &nx, const T &ny, const T &nz, const T &d)
	{
		normal.x = nx;
		normal.y = ny;
		normal.z = nz;
		dist = d;
	}

	// ����
	// n	��λ������
	// p	ƽ����һ��
	void Set(const _Vector3<T> &n, const _Vector3<T> &p)
	{
		normal = n;
		dist = n.Dot(p);
	}

	// ����
	// p0, p1, p2	ƽ���������������
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

	// ��ȡƽ����������ͬ�ĵ�
	// ����
	// p0, p1, p2	ƽ���������������
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

	// ����
	// p	�ռ�һ�������
	T DistanceTo(const _Vector3<T> &p) const 
	{
		return normal.Dot(p) - dist;
	}

	// ��ʹ������������
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
