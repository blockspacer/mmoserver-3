#pragma once

#ifndef __TYPES_H__
#define __TYPES_H__

#include <stdlib.h>
#include <stdio.h>

typedef char				Int8;
typedef short				Int16;
typedef int					Int32;

typedef unsigned char		Byte, Uint8;
typedef unsigned short		Word, Uint16;
typedef unsigned int		Dword, Uint32;
typedef unsigned int		Uint;
typedef float				Float;
typedef unsigned long		Ulong;
typedef double				Double;

#ifdef __GNUC__
typedef long long			Int64;
typedef unsigned long long	Qword, Uint64;
#else
typedef __int64				Int64;
typedef unsigned __int64	Qword, Uint64;
#endif

namespace neox
{

const int MAX_PATH_LEN = 256;

enum ResType
{
	RES_TYPE_UNKNOWN			= 0x00,
	RES_TYPE_FILE				= 0x01,

	RES_TYPE_TEXTURE			= 0x10,
	RES_TYPE_EFFECT				= 0x11,
	RES_TYPE_MATERIAL			= 0x12,
	RES_TYPE_MATERIAL_GROUP		= 0x13,
	RES_TYPE_TEXTURE_GROUP		= 0x14,

	RES_TYPE_SCENE				= 0x20,
	RES_TYPE_MESH				= 0x21,
	RES_TYPE_SKELANIM			= 0x22,
	RES_TYPE_SFX				= 0x23,
	RES_TYPE_TRACK				= 0x24,
	RES_TYPE_COMPONENT			= 0x25,

	RES_TYPE_FMOD_SOUND			= 0x40,
	RES_TYPE_FMOD_EVENT_PROJECT	= 0x41,

	RES_TYPE_MOVIE				= 0x50,
	RES_TYPE_SPACEMOVIE			= 0x51
};


namespace math3d
{
	template <class T> struct _Vector3;
	template <class T> struct _Matrix;	
	template <class T> struct _Rotation;
	template <class T> class _MatrixMN;
	template <class T> class _VectorN;
	template <class T> struct _DualQuaternion;
	template <class T> struct _Plane;
	template <class T> struct _Line3;
	template <class T> struct _Point2;
	template <class T> struct _Rect;
	template <class T> struct _CtrlCurve;

	struct Matrix33;
	struct Color32;
	struct ColorF;


	typedef _Vector3<Float> Vector3;
	typedef _Matrix<Float> Matrix;
	typedef _Rotation<Float> Rotation;
	typedef _MatrixMN<Float> MatrixMN;
	typedef _VectorN<Float> VectorN;
	typedef _DualQuaternion<Float> DualQuaternion;
	typedef _Plane<Float> Plane;
	typedef _Line3<Float> Line3;

	typedef _Point2<Int32> Point2;
	typedef _Point2<Float> Point2F;
	typedef Point2 Size2;
	typedef Point2F Size2F;

	typedef _Rect<Int32> Rect;
	typedef _Rect<Float> RectF;
	typedef _CtrlCurve<Float> CtrlCurve;
}

//////////////////////////////////////////////////
// 用来辅助模板函数在编译时判断一个类型是否内部是Float数组
struct FloatArrayType {};
struct NonFloatArrayType {};

template<typename T>
struct TypeTrait
{
	typedef NonFloatArrayType trait;
};

template<>
struct TypeTrait<math3d::Point2F>
{
	typedef FloatArrayType trait;
};

template<>
struct TypeTrait<math3d::ColorF>
{
	typedef FloatArrayType trait;
};

template<>
struct TypeTrait<math3d::Vector3>
{
	typedef FloatArrayType trait;
};

template<>
struct TypeTrait<math3d::Matrix>
{
	typedef FloatArrayType trait;
};

template<>
struct TypeTrait<math3d::Rotation>
{
	typedef FloatArrayType trait;
};

template<>
struct TypeTrait<math3d::Matrix33>
{
	typedef FloatArrayType trait;
};
//////////////////////////////////////////////////

struct UniqueID
{
	Dword data[4];
	bool operator < (const UniqueID& dst) const
	{
		for (int i = 0; i < 4; i++)
		{
			if (data[i] != dst.data[i])
			{
				return data[i] < dst.data[i];
			}
		}
		return false;
	}

	bool operator == (const UniqueID& dst) const
	{
		for (int i = 0; i < 4; i++)
		{
			if (data[i] != dst.data[i])
			{
				return false;
			}
		}
		return true;
	}

};

inline Dword DwordToDwordHash(Dword a)
{
	a -= (a<<6);
	a ^= (a>>17);
	a -= (a<<9);
	a ^= (a<<4);
	a -= (a<<3);
	a ^= (a<<10);
	a ^= (a>>15);

	return a;
}

inline Byte DwordToByteHash(Dword a)
{
	a -= (a<<6);
	a ^= (a>>17);
	a -= (a<<9);
	a ^= (a<<4);
	a -= (a<<3);
	a ^= (a<<10);
	a ^= (a>>15);

	Byte result = a ^ (a>>8) ^ (a >>16) ^(a >>24);
	return result;	
}

inline Word DwordToWordHash(Dword a)
{
	a -= (a<<6);
	a ^= (a>>17);
	a -= (a<<9);
	a ^= (a<<4);
	a -= (a<<3);
	a ^= (a<<10);
	a ^= (a>>15);

	Word result = a ^ (a >>16) ;
	return result;	
}

inline void FromString(UniqueID &id, const char *buf)
{
	sscanf(buf, "%08X-%08X-%08X-%08X", &id.data[0], &id.data[1], &id.data[2], &id.data[3]);
}

inline void ToString(const UniqueID &id, char *buf)
{
	sprintf(buf, "%08X-%08X-%08X-%08X", id.data[0], id.data[1], id.data[2], id.data[3]);
}

inline void FromString(long &value, const char *buf)
{
	sscanf(buf, "%ld", &value);
}

inline void FromString(Int32 &value, const char *buf)
{
	sscanf(buf, "%d", (int*)&value);
}

inline void FromString(Uint32 &value, const char *buf)
{
	sscanf(buf, "%u", &value);
}

inline void FromString(Float &value, const char *buf)
{
	value = (Float)atof(buf);
}

inline void FromString(Ulong &value, const char *buf)
{
	value = (Ulong)atol(buf);
}

inline void ToString(long value, char *buf)
{
	sprintf(buf, "%ld", value);
}

inline void ToString(Int32 value, char *buf)
{
	sprintf(buf, "%d", (int)value);
}

inline void ToString(Uint32 value, char *buf)
{
	sprintf(buf, "%u", value);
}

inline void ToString(Ulong value, char *buf)
{
	sprintf(buf, "%lu", value);
}

inline void ToString(Float value, char *buf)
{
	const Float very_small = 1e-4f;
	if (value < very_small && value > -very_small)
	{
		// 避免正负0问题
		value = .0f;
	}
	// 超土鳖的作法，来尽量保证浮点数读写误差
	sprintf(buf, "%f", value);
	value = (Float)atof(buf);
	sprintf(buf, "%f", value);
}

inline Dword f2dw(float value)
{
	return *reinterpret_cast<Dword*>(&value);
}

inline float dw2f(Dword value)
{
	return *reinterpret_cast<float*>(&value);
}

enum
{
	STATE_UNLOAD	= 0,
	STATE_LOADING	= 1,
	STATE_LOADED	= 2,
	STATE_FAILED	= 3,
};

} // namespace neox

#ifndef NULL
#define	NULL (void*)0
#endif

#define SafeRelease(obj) if(obj != NULL){ obj->Release(); obj = NULL;}

#endif
