#include <iostream>
#include "OftDetour.h"

using namespace std;

int test_detour()
{
	OftDetour* t1 = new OftDetour();
	t1->Init("detour/9.nav");
	int len = 0;
	std::vector<float> m_spos;
	std::vector<float> m_epos;
	m_spos.push_back(8.12799835);
	m_spos.push_back(9.99818420);
	m_spos.push_back(-40.0058632);

	m_epos.push_back(59.0436249);
	m_epos.push_back(0);
	m_epos.push_back(9.68192482);

	//const float* path = t1->GetPath(m_spos[0], m_spos[1], m_spos[2], m_epos[0], m_epos[1], m_epos[2], len);
	/*const float* path = t1->GetPath(m_spos, m_epos, len);
	if (path != nullptr)
	{
		for (int i = 0; i < len; i++)
		{
			printf("%f, %f, %f\n", path[i * 3], path[i * 3 + 1], path[i * 3 + 2]);
		}
	}*/

	float np[3];
	t1->findNearestPoly(m_epos[0], m_epos[1], m_epos[2], np, nullptr);


	system("pause");
	return 0;
}

int main(int argc, char* argv[])
{
	return test_detour();
}