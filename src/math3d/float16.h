#pragma once
#ifndef __HALF_FLOAT_H__
#define __HALF_FLOAT_H__

#include <math.h>
#include <stdio.h>
#include <iostream>

namespace neox
{
namespace math3d
{

/*

	16位浮点数
	数值范围: [-2^5*2047, 2^5*2047] 即([-65504.0, 65504.0])
	数值精度: 2^-14 即(6.103515625e-005)

	从float32到float16由于尾数截断会带来数值损失,
	数值损失的最大相对误差：[(2^13 - 1) * 2^(-23)] / (2 - 2^(-10)) (约0.48846e-4)
	例如：
	float32	 0 10001110 11111100011010100000000 (65535.996f)
	float16  0 11110 1111110001 (65504.0f)

*/

extern unsigned int _to_float[1 << 16];
extern unsigned short _base_table[1 << 9];
extern unsigned char _shift_table[1 << 9];

struct Float16
{
	unsigned short	ubit;

	static inline Float16 ToFloat16(float f)
	{
		Float16 h;
		unsigned int x = *(unsigned int*)(&f);
		h.ubit = _base_table[(x >> 23) & 0x1ff] + ((x & 0x007fffff) >> _shift_table[(x >> 23) & 0x1ff]);
		return h;
	}
	
	operator float() const
	{
		return *(float*)(&_to_float[ubit]);
	}

	Float16 operator - () const
	{
		Float16 h;
		h.ubit = ubit ^ 0x8000;
		return h;
	}

	Float16& operator += (Float16 h)
	{
		*this = ToFloat16 (float (*this) + float (h));
		return *this;
	}

	Float16& operator += (float h)
	{
		*this = ToFloat16 (float (*this) + h);
		return *this;
	}

	Float16& operator -= (Float16 h)
	{
		*this = ToFloat16 (float (*this) - float (h));
		return *this;
	}

	Float16& operator *= (Float16 h)
	{
		*this = ToFloat16 (float (*this) * float (h));
		return *this;
	}

	Float16& operator /= (Float16 h)
	{
		*this = ToFloat16 (float (*this) / float (h));
		return *this;
	}

	bool IsNormal() const
	{
		unsigned short e = ubit & 0x7c00;
		return e != 0 && e != 0x7c00;
	}

	bool IsDenormal() const
	{
		return ((ubit & 0x7c00) == 0) && ((ubit & 0x03ff) != 0);
	}

	bool IsZero() const
	{
		return (ubit & 0x7fff) == 0;
	}

	bool IsNan() const
	{
		return ((ubit & 0x7c00) == 0x7c00) && ((ubit & 0x03ff) != 0);
	}

	bool IsInf() const
	{
		return ((ubit & 0x7c00) == 0x7c00) && ((ubit & 0x03ff) == 0);
	}

	bool IsNeg() const
	{
		return (ubit & 0x8000) != 0;
	}

	bool IsEqual(Float16 f16, const float &eps = EPSILON) const
	{
		float diff = float(*this) - float(f16);
		if (diff > eps || diff < -eps)
		{
			return false;
		}
		return true;
	}

	bool operator < (const Float16& r)const
	{
		return float(*this) < float(r);
	}
	bool operator > (const Float16& r)const
	{
		return float(*this) > float(r);
	}

	unsigned short GetBits() const
	{
		return ubit;
	}

	void SetBits(unsigned short v)
	{
		ubit = v;
	}

	static Float16 PosInf()
	{
		Float16 h;
		h.ubit = 0x7c00;
		return h;
	}

	static Float16 NegInf()
	{
		Float16 h;
		h.ubit = 0xfc00;
		return h;
	}

	// GEN_TABLE宏
	// 定义了后，需要自己调用GenTable来生成float16 <-> float 转换用到的表
	// 不定义这个宏就直接用float16_data.inl文件里的表，这会编译进最终二进制文件。

#ifdef GEN_TABLE
	static void GenTable()
	{
		for (unsigned int i = 0; i < (1 << 16); ++i)
		{
			Float16 x;
			x.SetBits(i);
			if (x.IsZero())
			{
				_to_float[i] = ((x.ubit & 0x8000)<<16);
			}
			else if (x.IsNan())
			{
				_to_float[i] = ((x.ubit & 0x8000)<<16) | (0xff << 23) | ((x.ubit & 0x03ff) << 13);
			}
			else if (x.IsInf())
			{
				_to_float[i] = ((x.ubit & 0x8000)<<16) | (0xff << 23);
			}
			else if (x.IsDenormal())
			{
				unsigned short m = x.ubit & 0x03ff;
				int count = 0; // 尾数部分有几个前导0
				for (; (m & 0x0200) == 0; m <<= 1)
				{
					++count;
				}
				_to_float[i] = ((x.ubit & 0x8000)<<16) | ((-count + 112) << 23) | (((x.ubit << (count + 1)) & 0x03ff) << 13);
			}
			else
			{
				_to_float[i] = ((x.ubit & 0x8000)<<16) | ((((x.ubit >> 10) & 0x1f) + 112) << 23) | ((x.ubit & 0x03ff) << 13);
			}
		}

		for(unsigned int i = 0; i < 256; ++i)
		{
			int e = i - 127;
			if (e < -24)
			{
				_base_table[i|0x000] = 0x0000;
				_base_table[i|0x100] = 0x8000;
				_shift_table[i|0x000] = 24;
				_shift_table[i|0x100] = 24;
			}
			else if (e < -14)
			{
				_base_table[i|0x000] = (0x0400 >> (-e-14));
				_base_table[i|0x100] = (0x0400 >> (-e-14)) | 0x8000;
				_shift_table[i|0x000] = -e - 1;
				_shift_table[i|0x100] = -e - 1;
			}
			else if (e <= 15)
			{
				_base_table[i|0x000] = ((e + 15) << 10);
				_base_table[i|0x100] = ((e + 15) << 10) | 0x8000;
				_shift_table[i|0x000] = 13;
				_shift_table[i|0x100] = 13;
			}
			else if (e < 128)
			{
				_base_table[i|0x000] = 0x7c00;
				_base_table[i|0x100] = 0xfc00;
				_shift_table[i|0x000] = 24;
				_shift_table[i|0x100] = 24;
			}
			else
			{
				_base_table[i|0x000] = 0x7c00;
				_base_table[i|0x100] = 0xfc00;
				_shift_table[i|0x000] = 13;
				_shift_table[i|0x100] = 13;
			}
		}
	}

	static void SaveTable()
	{
		GenTable();

		// 把表写入文件
		FILE *fp = ::fopen("float16.cpp", "w");
		const char *head_info = "\n/* This is an automatically generated file. Do not edit. */\n\n";
		::fprintf(fp, head_info);
		::fprintf(fp, "namespace neox\n{\nnamespace math3d\n{\n\n");
		::fprintf(fp, "unsigned int	_to_float[1 << 16] = \n{\n");
		for (int i = 1; i <= sizeof(_to_float) / sizeof(_to_float[0]); ++i)
		{
			::fprintf(fp, "\t0x%p, ", _to_float[i-1]);
			if ((i & 0x7) == 0)
			{
				::fprintf(fp, "\n");
			}
		}
		::fprintf(fp, "\n};\n\n");
		::fprintf(fp, "unsigned short _base_table[1 << 9] = \n{\n");
		for (int i = 1; i <= sizeof(_base_table) / sizeof(_base_table[0]); ++i)
		{
			::fprintf(fp, "\t0x%p, ", _base_table[i-1]);
			if ((i & 0x7) == 0)
			{
				::fprintf(fp, "\n");
			}
		}
		::fprintf(fp, "\n};\n\n");
		::fprintf(fp, "unsigned char _shift_table[1 << 9] = \n{\n");
		for (int i = 1; i <= sizeof(_shift_table) / sizeof(_shift_table[0]); ++i)
		{
			::fprintf(fp, "\t0x%p, ", _shift_table[i-1]);
			if ((i & 0x7) == 0)
			{
				::fprintf(fp, "\n");
			}
		}
		::fprintf(fp, "\n};\n");
		::fprintf(fp, "\n} // namespace math3d\n} // namespace neox\n");
		::fclose(fp);
	}
#endif

};

struct PackVector3
{
	Float16 x, y, z;
	PackVector3()
	{}

	PackVector3(Float16 _x, Float16 _y, Float16 _z) : x(_x), y(_y), z(_z)
	{}

	inline bool operator != (const PackVector3 &pv3)
	{
		return !(operator==(pv3));
	}
	inline bool operator == (const PackVector3 &pv3)
	{
		return x.IsEqual(pv3.x) &&
			y.IsEqual(pv3.y) && z.IsEqual(pv3.z);
	}
};

struct PackRotation
{
	Float16 x, y, z, w;
	PackRotation()
	{}

	PackRotation(Float16 _x, Float16 _y, Float16 _z, Float16 _w) : x(_x), y(_y), z(_z), w(_w)
	{}

	inline bool operator != (const PackRotation &pack_rot)
	{
		return !(operator==(pack_rot));
	}
	inline bool operator == (const PackRotation &pack_rot)
	{
		return x.IsEqual(pack_rot.x) &&	y.IsEqual(pack_rot.y)
			&& z.IsEqual(pack_rot.z) && w.IsEqual(pack_rot.w);
	}
};

inline std::ostream& operator <<(std::ostream &os, Float16 h)
{
	os << float(h);
	return os;
}

inline std::istream& operator >>(std::istream &is, Float16 &h)
{
	float f;
	is >> f;
	h.ToFloat16(f);
	return is;
}

} // namespace math3d
} // namespace neox
#endif // __HALF_FLOAT_H__
