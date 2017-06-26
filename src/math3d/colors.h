#pragma once

#ifndef __COLORS_H__
#define __COLORS_H__

#include <stdio.h>
#include <string.h>

namespace neox
{
namespace math3d
{

struct Color32
{
	union 
	{
		struct 
		{
			Byte blue, green, red, alpha;
		};
		Dword color;
	};

	Color32():
		color(0xffffffff)
	{}
	
	Color32(Byte a, Byte r, Byte g, Byte b): 
		blue(b), green(g), red(r), alpha(a)
	{}

	explicit Color32(Dword c): 
		color(c)
	{}

	void Init(Dword c = 0xffffffff)
	{
		Set(c);
	}

	void Init(Byte a, Byte r, Byte g, Byte b)
	{
		Set(a, r, g, b);
	}

	void Set(Byte a, Byte r, Byte g, Byte b)
	{
		red = r;
		green = g;
		blue = b;
		alpha = a;
	}

	operator Dword() const
	{
		Dword c = alpha<<24|red<<16|green<<8|blue;//(Byte(alpha), Byte(red), Byte(green), Byte(blue));
		return c;
	}

	void Set(Dword c)
	{
		color = c;
	}

	void SetColor(Byte r, Byte g, Byte b)
	{
		red = r;
		green = g;
		blue = b;
	}

	void SetAlpha(Byte a)
	{
		alpha = a;
	}

	void Intrp(const Color32 &color1, const Color32 &color2, Float f)
	{
		alpha = Clamp(color1.alpha + (color2.alpha - color1.alpha) * f);
		red = Clamp(color1.red + (color2.red - color1.red) * f);
		green = Clamp(color1.green + (color2.green - color1.green) * f);
		blue = Clamp(color1.blue + (color2.blue - color1.blue) * f);
	}

	bool operator ==(const Color32 &c) const
	{
		return color == c.color;
	}

	bool operator !=(const Color32 &c) const
	{
		return !(*this == c);
	}

	Color32& operator =(const Color32 &color)
	{
		red = color.red;
		blue = color.blue;
		green = color.green;
		alpha = color.alpha;
		return *this;
	}

private:
	Byte Clamp(Float f) const
	{
		if (f < 0)
		{
			return 0;
		}
		
		if (f > 255)
		{
			return 255;
		}
		
		return Byte(f);
	}
};

struct ColorF
{
	Float red, green, blue, alpha;
	
	ColorF(): 
		red(1.0), green(1.0), blue(1.0), alpha(1.0)
	{}

	ColorF(Float a, Float r, Float g, Float b): 
		red(r), green(g), blue(b), alpha(a)
	{}
	
	ColorF(const Color32 &color): 
		red(Float(color.red / 255.0)), green(Float(color.green / 255.0)), 
		blue(Float(color.blue / 255.0)), alpha(Float(color.alpha / 255.0))
	{}

	void Init(Float a = 1.0f, Float r = 1.0f, Float g = 1.0f, Float b = 1.0f)
	{
		Set(a, r, g, b);
	}
	
	void Set(Float a = 1.0, Float r = 1.0, Float g = 1.0, Float b = 1.0)
	{
		alpha = a;
		red = r;
		green = g;
		blue = b;
	}

	operator Dword() const
	{
		Color32 c(
			Byte(255.0 * DoClamp(alpha) + 0.5f), 
			Byte(255.0 * DoClamp(red) + 0.5f), 
			Byte(255.0 * DoClamp(green) + 0.5f), 
			Byte(255.0 * DoClamp(blue) + 0.5f));
		return c.color;
	}

	ColorF operator *(Float factor) const
	{
		return ColorF(alpha, red * factor, green * factor, blue * factor);
	}

	ColorF& operator *=(Float factor)
	{
		red *= factor;
		green *= factor;
		blue *= factor;
		return *this;
	}

	ColorF operator +(const ColorF &c)
	{
		return ColorF(alpha, red + c.red, green + c.green, blue + c.blue);
	}

	ColorF& operator +=(const ColorF &c)
	{
		red += c.red;
		green += c.green;
		blue += c.blue;
		return *this;
	}

	void Clamp()
	{
		red = DoClamp(red);
		green = DoClamp(green);
		blue = DoClamp(blue);
	}

	void Intrp(const ColorF &color1, const ColorF &color2, Float factor)
	{
		alpha = color1.alpha + (color2.alpha - color1.alpha) * factor;
		red = color1.red + (color2.red - color1.red) * factor;
		green = color1.green + (color2.green - color1.green) * factor;
		blue = color1.blue + (color2.blue - color1.blue) * factor;
	}
private:
	Float DoClamp(Float v) const
	{
		if (v < 0.0)
		{
			return 0.0;
		}
		
		if (v > 1.0)
		{
			return 1.0;
		}
		
		return v;
	}
};

} // namespace math3d

inline void FromString(math3d::Color32 &value, char *buf)
{
	math3d::Color32 result;

	char *p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	result.alpha = atoi(buf);

	buf = p + 1;
	p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	result.red = atoi(buf);

	buf = p + 1;
	p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	result.green = atoi(buf);

	result.blue = atoi(p + 1);
	value = result;
}

inline void ToString(const math3d::Color32 &value, char *buf)
{
	sprintf(buf, "%d,%d,%d,%d", value.alpha, value.red, value.green, value.blue);
}

inline void FromString(math3d::ColorF &value, char *buf)
{
	math3d::ColorF result;

	char *p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	result.red = (Float)atof(buf);

	buf = p + 1;
	p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	result.green = (Float)atof(buf);

	buf = p + 1;
	p = strchr(buf, ',');
	if (p == 0)
	{
		return;
	}

	*p = '\0';
	result.blue = (Float)atof(buf);

	result.alpha = (Float)atof(p + 1);
	value = result;
}

inline void ToString(const math3d::ColorF &value, char *buf)
{
	sprintf(buf, "%f,%f,%f,%f", value.red, value.green, value.blue, value.alpha);
}

} // namespace neox

#endif // __COLORS_H__
