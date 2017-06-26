#include "shape.h"

namespace neox
{
	namespace h12map
	{
		bool _PtInConvexPolygon(math3d::Point2F& point, math3d::Point2F vertices[], int n_vertices)
		{
			int sign = 0;
			for (int i = 0; i<n_vertices; i++)
			{
				math3d::Point2F seg0 = vertices[i];
				math3d::Point2F seg1 = vertices[(i + 1) == n_vertices ? 0 : i + 1];
				math3d::Point2F affine_segment = seg1 - seg0;
				math3d::Point2F affine_point = point - seg0;
				float k = _XProduct(affine_segment, affine_point);
				if (fabs(k) < math3d::EPSILON) return true;
				int the_sign = k>0 ? 1 : -1;
				if (sign == 0)
					sign = the_sign;
				else if (the_sign != sign)
					return false;
			}
			return true;
		}

		Shape* GenerateShape(int shape_type, math3d::Point2F& pos, math3d::Point2F& dire, float arg1, float arg2)
		{
			Shape* p = nullptr;
			switch (shape_type)
			{
			case SHAPE_INFINITY:
				p = new Infinity();
				break;
			case SHAPE_CIRCLE:
				p = new Circle(pos, arg1);
				break;
			case SHAPE_SECTOR:
				p = new Sector(pos, dire, arg2, arg1);
				break;
			case SHAPE_RECT:
				p = new BottomRect(pos, dire, arg2, arg1);
				break;
			case SHAPE_RECT_CENTER:
				p = new CenterRect(pos, dire, arg2, arg1);
				break;
			default:
				p = new Infinity();
				break;
			}
			return p;
		}

		void BottomRect::_CalcVertices()
		{
			math3d::Point2F ccw90(-m_dire.y, m_dire.x);
			math3d::Point2F hl = ccw90 * m_width * 0.5f;
			math3d::Point2F vec = m_dire * m_length;
			m_vertices[0] = m_pos + hl;
			m_vertices[3] = m_pos - hl;
			m_vertices[1] = m_vertices[0] + vec;
			m_vertices[2] = m_vertices[3] + vec;
		}

		void CenterRect::_CalcVertices()
		{
			math3d::Point2F ccw90(-m_dire.y, m_dire.x);
			math3d::Point2F hl = ccw90 * m_width * 0.5f;
			math3d::Point2F vec = m_dire * m_length;
			math3d::Point2F pos_minus_hvec = m_pos - vec * 0.5f;
			m_vertices[0] = pos_minus_hvec + hl;
			m_vertices[3] = pos_minus_hvec - hl;
			m_vertices[1] = m_vertices[0] + vec;
			m_vertices[2] = m_vertices[3] + vec;
		}

		void Rect::SetPosition(math3d::Point2F& pos)
		{
			m_pos = pos;
			_CalcVertices();
		}

		void Rect::SetArg1(float arg1)
		{
			m_length = arg1;
			_CalcVertices();
		}

		void Rect::SetArg2(float arg2)
		{
			m_width = arg2;
			_CalcVertices();
		}

		bool Rect::IsPointIn(math3d::Point2F& pt)
		{
			return _PtInConvexPolygon(pt, m_vertices, 4);
		}

		bool Sector::IsPointIn(math3d::Point2F& pt)
		{
			math3d::Point2F pos_pt = pt - m_pos;
			if (pos_pt.IsZero()) return true;
			if (pos_pt.LengthSqr() > m_radius_sqr) return false;

			float theta0 = atan2f(m_dire.y, m_dire.x);
			float theta1 = atan2f(pos_pt.y, pos_pt.x);
			float delta_theta = fabs(theta0 - theta1);
			if (delta_theta > Py_MATH_PI)
				delta_theta = float(Py_MATH_PI) * 2.0f - delta_theta;
			return delta_theta <= m_rad / 2.0f;
		}

		std::string Infinity::GetDebugInfo(float y)
		{
			std::string d("shape: Infinity");
			return d;
		}

		std::string Rect::GetDebugInfo(float y)
		{
			//PyObject* d = PyDict_New();
			//PyDict_SetItemString(d, "shape", PyString_FromString("Rect"));
			//PyObject* vertices = PyList_New(4);
			//for (int i = 0; i<4; i++)
			//{
			//	PyVector* vertex = Vector_new();
			//	vertex->vector = math3d::Vector3(m_vertices[i].x, y, m_vertices[i].y);
			//	PyList_SetItem(vertices, i, (PyObject*)vertex);
			//}
			//PyDict_SetItemString(d, "vertices", vertices);
			return "";
		}

		std::string Sector::GetDebugInfo(float y)
		{
			//PyObject* d = PyDict_New();
			//PyDict_SetItemString(d, "shape", PyString_FromString("Sector"));
			//float theta0 = atan2(m_dire.y, m_dire.x);
			//float half_rad = m_rad / 2.0f;
			//PyDict_SetItemString(d, "theta2", PyFloat_FromDouble(theta0 + half_rad));
			//PyDict_SetItemString(d, "theta1", PyFloat_FromDouble(theta0 - half_rad));
			//PyVector* center = Vector_new();
			//center->vector = math3d::Vector3(m_pos.x, y, m_pos.y);
			//PyDict_SetItemString(d, "center", (PyObject*)center);
			//PyDict_SetItemString(d, "radius", PyFloat_FromDouble(m_radius));
			//return d;
			return "";
		}

		std::string Circle::GetDebugInfo(float y)
		{
			//PyObject* d = PyDict_New();
			//PyDict_SetItemString(d, "shape", PyString_FromString("Circle"));
			//PyVector* center = Vector_new();
			//center->vector = math3d::Vector3(m_pos.x, y, m_pos.y);
			//PyDict_SetItemString(d, "center", (PyObject*)center);
			//PyDict_SetItemString(d, "radius", PyFloat_FromDouble(m_radius));
			//return d;
			return "";
		}
	}
}

