#pragma once

#ifndef __FIXED_H__
#define __FIXED_H__

namespace neox
{

namespace math3d
{

template <int Precision, class Int = int>
class _Fixed
{
private:
	enum
	{
		One = 1 << Precision
	};

	Int m_value;
public:
	_Fixed(): m_value(0) {}
	explicit _Fixed(float x): m_value(Int(x * One)) {}
	explicit _Fixed(int x): m_value(x << Precision) {}
	_Fixed(int p, int q): m_value((p << Precision) / q) {}

	_Fixed operator +(const _Fixed &other) const
	{
		_Fixed result(*this);
		return result += other;
	}

	_Fixed operator -(const _Fixed &other) const
	{
		_Fixed result(*this);
		return result -= other;
	}

	_Fixed operator *(const _Fixed &other) const
	{
		_Fixed result(*this);
		return result *= other;
	}

	_Fixed operator *(int other) const
	{
		_Fixed result(*this);
		return result *= other;
	}

	_Fixed operator /(const _Fixed &other) const
	{
		_Fixed result(*this);
		return result /= other;
	}

	_Fixed operator /(int other) const
	{
		_Fixed result(*this);
		return result /= other;
	}

	_Fixed operator %(const _Fixed &other) const
	{
		_Fixed result(*this);
		return result %= other;
	}

	_Fixed& operator +=(const _Fixed &other)
	{
		m_value += other.m_value;
		return *this;
	}

	_Fixed& operator -=(const _Fixed &other)
	{
		m_value -= other.m_value;
		return *this;
	}

	_Fixed& operator *=(const _Fixed &other)
	{
		m_value = m_value * other.m_value >> Precision;
		return *this;
	}

	_Fixed& operator *=(int other)
	{
		m_value *= other;
		return *this;
	}

	_Fixed& operator /=(const _Fixed &other)
	{
		m_value = (m_value << Precision) / other.m_value;
		return *this;
	}

	_Fixed& operator /=(int other)
	{
		m_value /= other;
		return *this;
	}

	_Fixed& operator %=(const _Fixed &other)
	{
		m_value %= other.m_value;
		return *this;
	}

	bool operator ==(const _Fixed &other) const
	{
		return m_value == other.m_value;
	}

	bool operator !=(const _Fixed &other) const
	{
		return !operator ==(other);
	}

	bool operator <(const _Fixed &other) const
	{
		return m_value < other.m_value;
	}

	bool operator >(const _Fixed &other) const
	{
		return other.operator <(*this);
	}

	bool operator >=(const _Fixed &other) const
	{
		return !operator <(other);
	}

	bool operator <=(const _Fixed &other) const
	{
		return !other.operator <(*this);
	}

	friend _Fixed operator *(int x, const _Fixed &other)
	{
		return other.operator *(x);
	}

	operator int() const
	{
		return m_value >> Precision;
	}
};

} // namespace math3d
} // namespace neox

#endif // __FIXED_H__
