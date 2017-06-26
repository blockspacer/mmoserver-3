#pragma once

#ifndef __RECTS_H__
#define __RECTS_H__


namespace neox
{
namespace math3d
{

template <class T>
struct _Rect
{
	typedef T	Base;
	
	enum ScaleMode
	{
		SCALEMODE_CENTER,				//参照矩形中心点缩放
		SCALEMODE_TOPLEFT,				//参照矩形左上角缩放
		SCALEMODE_ORIGIN,				//参照原点缩放
	};
	
	T left;
	T top;
	T right;
	T bottom;
	
	_Rect(): 
		left(0), top(0), right(0), bottom(0)
	{}
	
	_Rect(const T &_left, const T &_top, const T &_right, const T &_bottom): 
		left(_left), top(_top), right(_right), bottom(_bottom)
	{}

	_Rect(const _Point2<T> &left_top_pos, const _Point2<T> &size)
	{
		Set(left_top_pos, size);
	}
	
	void Set(const T &_left, const T &_top, const T &_right, const T &_bottom)
	{
		left = _left;
		top = _top;
		right = _right;
		bottom = _bottom;
	}

	void Set(const _Point2<T> &left_top_pos, const _Point2<T> &size)
	{
		left = left_top_pos.x;
		top = left_top_pos.y;
		right = left_top_pos.x + size.x;
		bottom = left_top_pos.y + size.y;
	}
	
	T Width() const
	{
		return right - left;
	}
	
	T Height() const
	{
		return bottom - top;
	}
	
	_Point2<T> TopLeft() 
	{
		return _Point2<T>(left, top);
	}
	
	_Point2<T> BottomRight()
	{
		return _Point2<T>(right, bottom);
	}
	
	bool Contains(const T &x, const T &y) const
	{
		return (x >= left && x < right && y >= top && y < bottom);
	}
	
	bool Contains(const _Point2<T> &pt) const
	{
		return Contains(pt.x, pt.y);
	}
	
	void SetScale(const T &scale, ScaleMode mode)
	{
		T delta_width = Width() * (scale - 1);
		T delta_height = Height() * (scale - 1);
		
		switch (mode)
		{
		case SCALEMODE_CENTER:
			delta_width /= 2;
			delta_height /= 2;
			
			left -= delta_width;
			top -= delta_height;
			right += delta_width;
			bottom += delta_height;
			
			break;
			
		case SCALEMODE_TOPLEFT:
			right += delta_width;
			bottom += delta_height;
			
			break;
		
		case SCALEMODE_ORIGIN:
			left *= scale;
			right *= scale;
			top *= scale;
			bottom *= scale;
			
			break;
		}
	}
	
	void MoveTo(const T &x, const T &y)
	{
		T width = Width(), height = Height();
		
		left = x;
		right = x + width;
		top = y;
		bottom = y + height;
	}
	
	void Inc(const T &delta)
	{
		left -= delta;
		right += delta;
		top -= delta;
		bottom += delta;
	}
	
	void Dec(const T &delta)
	{
		Inc(-delta);
	}
	
	_Rect operator +(const _Point2<T> &p) const
	{
		_Rect rect(*this);
		return rect += p;
	}
	
	_Rect& operator +=(const _Point2<T> &p)
	{
		left += p.x;
		right += p.x;
		top += p.y;
		bottom += p.y;
		return *this;
	}

	_Rect operator *(const T &scale) const
	{
		_Rect rect(*this);
		return rect *= scale;
	}

	_Rect& operator *=(const T &scale)
	{
		SetScale(scale, SCALEMODE_ORIGIN);
		return *this;
	}
	
	void MirrorHoriz()
	{
		Swap(left, right);
	}
	
	void MirrorVert()
	{
		Swap(top, bottom);
	}
private:
	void Swap(T &x, T &y)
	{
		T temp = x;
		x = y;
		y = temp;
	}
};

} // namespace math3d
} // namespace neox

#endif // __RECTS_h__