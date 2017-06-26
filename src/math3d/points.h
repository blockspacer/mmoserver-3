#pragma once

#ifndef __POINTS_H__
#define __POINTS_H__

namespace neox
{
namespace math3d
{

template <class T>
struct _Point2
{
	typedef T		Base;
	
	T x;
	T y;
	
	_Point2(): 
		x(0), y(0)
	{}
	
	_Point2(const T &_x, const T &_y): 
		x(_x), y(_y)
	{}
	
	void Set(const T &_x, const T &_y)
	{
		x = _x;
		y = _y;
	}

	bool operator <(const _Point2 &other) const
	{
		if (x < other.x)
		{
			return true;
		}
		if (x == other.x)
		{
			return y < other.y;
		}
		return false;
	}
	
	bool operator ==(const _Point2 &other) const
	{
		return (x == other.x && y == other.y);
	}
	
	bool operator !=(const _Point2 &other) const
	{
		return !(*this == other);
	}
	
	_Point2 operator +(const _Point2 &other) const
	{
		return _Point2(x + other.x, y + other.y);
	}
	
	_Point2& operator +=(const _Point2 &other)
	{
		x += other.x;
		y += other.y;		
		return *this;
	}
	
	_Point2 operator -(const _Point2 &other) const
	{
		return _Point2(x - other.x, y - other.y);
	}
	
	_Point2 operator -=(const _Point2 &other)
	{
		x -= other.x;
		y -= other.y;
		return *this;
	}
	
	_Point2 operator -() const
	{
		return _Point2(-x, -y);
	}
	
	_Point2 operator *(const T &factor) const
	{
		return _Point2(x * factor, y * factor);
	}
	
	_Point2 operator *(const _Point2 &v)
	{
		return _Point2(x * v.x, y * v.y);
	}

	_Point2 operator /(const T &factor) const
	{
		return _Point2(x / factor, y / factor);
	}

	_Point2 operator /(const _Point2 &v)
	{
		return _Point2(x /v.x, y/v.y);
	}

	_Point2& operator *=(const T &factor)
	{
		x *= factor;
		y *= factor;
		return *this;
	}

	T Dot(const _Point2 &pt) const
	{
		return x * pt.x + y * pt.y ;
	}

	T LengthSqr() const
	{
		return Dot(*this);
	}

	T Length() const
	{
		return (T)sqrt(LengthSqr());
	}

	bool IsZero() const
	{
		static const _Point2 ZERO_PT((T)0, (T)0);
		return *this == ZERO_PT;
	}

	const _Point2& Normalize(const T &scale = 1)
	{
		T len = Length();
		*this *= (scale / len);
		return *this;
	}

	void Intrp(const _Point2 &pt0, const _Point2 &pt1, const T &u)
	{
		x = pt0.x + (pt1.x - pt0.x) * u;
		y = pt0.y + (pt1.y - pt0.y) * u;
	}
};

} // namespace math3d

template <class T>
void FromString(math3d::_Point2<T> &value, char *buf)
{	
	char *p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}
	*p = '\0';
	FromString(value.x, buf);
	buf = p + 1;
	FromString(value.y, buf);
}

template <class T>
void ToString(const math3d::_Point2<T> &value, char *buf)
{
	char data_buf[2][256];

	ToString(value.x, data_buf[0]);
	ToString(value.y, data_buf[1]);

	sprintf(buf, "%s,%s", data_buf[0], data_buf[1]);
}

} // namespace neox

#endif