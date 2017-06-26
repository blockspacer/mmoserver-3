#ifndef __PYSHAPE_H__
#define __PYSHAPE_H__
#include <string>

#include "math3d/types.h"
#include "math3d/mathconsts.h"
#include "math3d/vectors.h"
#include "math3d/points.h"

#define SHAPE_INFINITY 0
#define SHAPE_CIRCLE 1
#define SHAPE_SECTOR 2
#define SHAPE_RECT 3
#define SHAPE_RECT_CENTER 4
#define SHAPE_POLYGON 6

#define BOTTOM_CENTER 1
#define CENTER 2


const Float Py_MATH_PI = 3.141592653589793f;

namespace neox
{
	namespace h12map
	{
		bool _PtInConvexPolygon(math3d::Point2F& point, math3d::Point2F vertices[], int n_vertices);
		inline float _XProduct(math3d::Point2F& a, math3d::Point2F& b) { return a.x * b.y - a.y * b.x; }

		

		class Shape
		{
		public:
			Shape(int shape_type) : shape_type(shape_type), m_pos(math3d::Point2F(0, 0)) {}
			Shape(int shape_type, math3d::Point2F& pos) :shape_type(shape_type), m_pos(pos) {}
			virtual ~Shape() {}
			virtual bool IsPointIn(math3d::Point2F& pt) = 0;
			virtual void GetPosition(math3d::Point2F& pos) { pos = m_pos; }
			virtual void SetPosition(math3d::Point2F& pos) { m_pos = pos; }
			virtual void GetDirection(math3d::Point2F& dire) {}
			virtual void SetDirection(math3d::Point2F& dire) {}
			virtual float GetArg1() = 0;
			virtual void SetArg1(float arg1) = 0;
			virtual float GetArg2() = 0;
			virtual void SetArg2(float arg2) = 0;
			virtual std::string GetDebugInfo(float y) = 0;
			int shape_type;
		protected:
			math3d::Point2F m_pos;
		};

		// 全部覆盖
		class Infinity : public Shape
		{
		public:
			Infinity() : Shape(SHAPE_INFINITY) {}
			~Infinity() {}
			inline bool IsPointIn(math3d::Point2F& pt) { return true; }
			inline float GetArg1() { return 0; }
			inline void SetArg1(float arg1) {}
			inline float GetArg2() { return 0; }
			inline void SetArg2(float arg2) {}
			std::string GetDebugInfo(float y);
		};


		class Rect : public Shape
		{
		public:
			Rect(math3d::Point2F& pos, math3d::Point2F& dire, float width, float length) : Shape(SHAPE_RECT, pos),
				m_dire(dire), m_width(width), m_length(length) {}
			~Rect() {}
			inline float GetArg1() { return m_length; }
			void SetArg1(float arg1);
			inline float GetArg2() { return m_width; }
			void SetArg2(float arg2);
			void SetPosition(math3d::Point2F& pos);
			bool IsPointIn(math3d::Point2F& pt);
			inline void SetDirection(math3d::Point2F& dire) { m_dire = dire; _CalcVertices(); }
			inline void GetDirection(math3d::Point2F& dire) { dire = m_dire; }
			std::string GetDebugInfo(float y);
		protected:
			virtual void _CalcVertices() = 0;
			math3d::Point2F m_vertices[4];
			math3d::Point2F m_dire;
			float m_width, m_length;
		};

		// 底部矩形
		class BottomRect : public Rect
		{
		public:
			BottomRect(math3d::Point2F& pos, math3d::Point2F& dire, float width, float length) :
				Rect(pos, dire, width, length) {
				_CalcVertices();
			};
			~BottomRect() {}
		protected:
			virtual void _CalcVertices();
		};

		// 中心矩形
		class CenterRect : public Rect
		{
		public:
			CenterRect(math3d::Point2F& pos, math3d::Point2F& dire, float width, float length) :
				Rect(pos, dire, width, length) {
				_CalcVertices();
			};
			~CenterRect() {}
		protected:
			virtual void _CalcVertices();
		};

		// 扇形
		class Sector : public Shape
		{
		public:
			Sector(math3d::Point2F& pos, math3d::Point2F& dire, float rad, float radius) :
				Shape(SHAPE_SECTOR, pos), m_dire(dire), m_rad(rad), m_radius(radius), m_radius_sqr(radius*radius) {}
			~Sector() {}
			inline float GetArg1() { return m_radius; }
			inline void SetArg1(float arg1) { m_radius = arg1; m_radius_sqr = arg1*arg1; }
			inline float GetArg2() { return m_rad; }
			inline void SetArg2(float arg2) { m_rad = arg2; }
			bool IsPointIn(math3d::Point2F& pt);
			inline void SetDirection(math3d::Point2F& dire) { m_dire = dire; }
			inline void GetDirection(math3d::Point2F& dire) { dire = m_dire; }
			std::string GetDebugInfo(float y);
		private:
			math3d::Point2F m_dire;
			float m_rad, m_radius, m_radius_sqr;
		};

		class Circle : public Shape
		{
		public:
			Circle(math3d::Point2F& pos, float radius) :
				Shape(SHAPE_CIRCLE, pos), m_radius(radius), m_radius_sqr(radius*radius) {}
			~Circle() {}
			inline float GetArg1() { return m_radius; }
			inline void SetArg1(float arg1) { m_radius = arg1; m_radius_sqr = arg1*arg1; }
			inline float GetArg2() { return 0; }
			inline void SetArg2(float arg2) {}
			inline bool IsPointIn(math3d::Point2F& pt) { return (pt - m_pos).LengthSqr() <= m_radius_sqr; }
			std::string GetDebugInfo(float y);
		private:
			float m_radius, m_radius_sqr;
		};

		Shape* GenerateShape(int shape_type, math3d::Point2F& pos, math3d::Point2F& dire, float arg1, float arg2);
	}
}

#endif //__PYMOVEUNIT_H__