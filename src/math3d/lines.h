#pragma once

#ifndef __LINES_H__
#define __LINES_H__


namespace neox
{
namespace math3d
{

template <class T> struct _Plane;

template <class T>
struct _Line3
{
	_Vector3<T> p0;
	_Vector3<T> dir;

	_Line3()
	{}

	_Line3(const _Vector3<T> &_p0, const _Vector3<T> &_p1)
	{
		Set(_p0, _p1);
	}

	void Set(const _Vector3<T> &_p0, const _Vector3<T> &_p1)
	{
		p0 = _p0;
		dir = _p1 - _p0;
	}

	void Evaluate(const T &t, _Vector3<T> &point) const
	{
		point.x = p0.x + dir.x * t;
		point.y = p0.y + dir.y * t;
		point.z = p0.z + dir.z * t;
	}

	_Vector3<T> operator [](const T &t) const
	{
		_Vector3<T> point;
		Evaluate(t, point);
		return point;
	}

	// 点到直线（线段）的距离，is_seg表示直线是否当成线段
	T DistanceTo(const _Vector3<T> &point, bool is_seg = false) const
	{
		T t = ProjectPoint(point);
		if (!is_seg || (t >= 0 && t <= 1))
		{
			_Vector3<T> perp_foot;
			Evaluate(t, perp_foot);
			return perp_foot.Distance(point);
		}
		if (t < 0)
		{
			return p0.Distance(point);
		}
		_Vector3<T> p1(p0);
		p1 += dir;
		return p1.Distance(point);
	}

	T DistanceTo(const _Vector3<T> &point, _Vector3<T> &nearest_pt, bool is_seg = false) const
	{
		T t = ProjectPoint(point);
		if (!is_seg || (t >= 0 && t <= 1))
		{
			Evaluate(t, nearest_pt);
			return nearest_pt.Distance(point);
		}
		if (t < 0)
		{
			nearest_pt = p0;
			return nearest_pt.Distance(point);
		}
		nearest_pt = p0;
		nearest_pt += dir;
		return nearest_pt.Distance(point);
	}

	// 点到直线的投影，返回直线上投影点的参数t
	T ProjectPoint(const _Vector3<T> &point) const
	{
		T len_sqr = dir.LengthSqr();
		_Vector3<T> temp(point);
		temp -= p0;
		return temp.Dot(dir) / len_sqr;
	}

	// 与平行于坐标平面的平面求交点的快速算法 
	bool IntersectPlaneYZ(const T &x, _Vector3<T> &point, T &t) const
	{
		if (Abs(dir.x) < EPSILON)
		{
			return false;
		}
		t = (x - p0.x) / dir.x;
		point.x = x;
		point.y = p0.y + dir.y * t;
		point.z = p0.z + dir.z * t;
		return true;
	}

	bool IntersectPlaneXZ(const T &y, _Vector3<T> &point, T &t) const
	{
		if (Abs(dir.y) < EPSILON)
		{
			return false;
		}
		t = (y - p0.y) / dir.y;
		point.x = p0.x + dir.x * t;
		point.y = y;
		point.z = p0.z + dir.z * t;
		return true;
	}

	bool IntersectPlaneXY(const T &z, _Vector3<T> &point, T &t) const
	{
		if (Abs(dir.z) < EPSILON)
		{
			return false;
		}
		t = (z - p0.z) / dir.z;
		point.x = p0.x + dir.x * t;
		point.y = p0.y + dir.y * t;
		point.z = z;
		return true;
	}

	int IntersectPlane(const _Plane<T> &plane, T &t, T eps = (T)EPSILON) const
	{
		T dot = dir.Dot(plane.normal);

		if (fabs(dot) <= eps)
		{
			if (fabs(plane.DistanceTo(p0)) <= (T)EPSILON)
			{
				return LINE_INTERSECT_EVERYWHERE;
			}
			else
			{
				return LINE_INTERSECT_NOWHERE;
			}
		}

		t = -plane.DistanceTo(p0) / dot;
		return LINE_INTERSECT_SOMEWHERE;
	}
};


template <class T>
inline T LineDistance(const _Line3<T> &line1, const _Line3<T> &line2,
	bool is_seg1 = false, bool is_seg2 = false)
{
	// 两直线（线段）的距离，is_seg1和is_seg2分别表示两直线是否当成线段

	_Vector3<T> n;
	line1.dir.Cross(line2.dir, n);
	T len = n.Length();
	if (len < EPSILON)
	{
		// 两直线平行
		if (!is_seg1 || !is_seg2)
		{
			return line1.DistanceTo(line2.p0);
		}

		_Vector3<T> p2(line2.p0);
		p2 += line2.dir;
		T t0 = line1.ProjectPoint(line2.p0);
		T t1 = line1.ProjectPoint(p2);
		if (t0 < 0 && t1 < 0)
		{
			return line1.p0.Distance(t0 < t1 ? p2 : line2.p0);
		}
		if (t0 > 1 && t1 > 1)
		{
			_Vector3<T> p1(line1.p0);
			p1 += line1.dir;
			return p1.Distance(t0 > t1 ? p2 : line2.p0);
		}

		_Vector3<T> perp_foot;
		line1.Evaluate(t0, perp_foot);
		return perp_foot.Distance(line2.p0);
	}

	n /= len;
	T dist;
	if (!is_seg1 && !is_seg2)
	{
		_Plane<T> plane(n, line1.p0);
		dist = plane.DistanceTo(line2.p0);
		return dist < 0 ? -dist : dist;
	}
	if (!is_seg1)
	{
		return LineDistToLineSeg(line1, line2, n);
	}
	if (!is_seg2)
	{
		return LineDistToLineSeg(line2, line1, n);
	}

	_Vector3<T> n0;
	_Plane<T> temp;
	T t1, t2;

	n.Cross(line2.dir, n0);
	temp.Set(n0, line2.p0);
	line1.IntersectPlane(temp, t1);

	n.Cross(line1.dir, n0);
	temp.Set(n0, line1.p0);
	line2.IntersectPlane(temp, t2);

	if (t1 >= 0 && t1 <= 1)
	{
		if (t2 >= 0 && t2 <= 1)
		{
			_Plane<T> plane(n, line1.p0);
			dist = plane.DistanceTo(line2.p0);
			return dist < 0 ? -dist : dist;
		}
		if (t2 < 0)
		{
			return line1.DistanceTo(line2.p0, true);
		}
		_Vector3<T> p1(line2.p0);
		p1 += line2.dir;
		return line1.DistanceTo(p1, true);
	}
	if (t2 >= 0 && t2 <= 1)
	{
		if (t1 < 0)
		{
			return line2.DistanceTo(line1.p0, true);
		}
		_Vector3<T> p1(line1.p0);
		p1 += line1.dir;
		return line2.DistanceTo(p1, true);
	}

	_Vector3<T> near1(line1.p0), near2(line2.p0);
	if (t1 > 1)
	{
		near1 += line1.dir;
	}
	if (t2 > 1)
	{
		near2 += line2.dir;
	}

	T t;
	t = line1.ProjectPoint(near2);
	if (t >= 0 && t <= 1)
	{
		_Vector3<T> perp_foot;
		line1.Evaluate(t, perp_foot);
		return perp_foot.Distance(near2);
	}
	t = line2.ProjectPoint(near1);
	if (t >= 0 && t <= 1)
	{
		_Vector3<T> perp_foot;
		line2.Evaluate(t, perp_foot);
		return perp_foot.Distance(near1);
	}
	return near1.Distance(near2);
}

template <class T>
inline T LineDistToLineSeg(const _Line3<T> &line, const _Line3<T> &line_seg,
	const _Vector3<T> &normal)
{
	_Vector3<T> n;
	normal.Cross(line.dir, n);
	_Plane<T> temp(n, line.p0);
	T t;
	line_seg.IntersectPlane(temp, t);
	if (t >= 0 && t <= 1)
	{
		_Plane<T> plane(normal, line.p0);
		T dist = plane.DistanceTo(line_seg.p0);
		return dist < 0 ? -dist : dist;
	}
	if (t < 0)
	{
		return line.DistanceTo(line_seg.p0);
	}
	_Vector3<T> p1(line_seg.p0);
	p1 += line_seg.dir;
	return line.DistanceTo(p1);
}

} // namespace math3d
} // namespace neox


#endif // __LINES_H__
