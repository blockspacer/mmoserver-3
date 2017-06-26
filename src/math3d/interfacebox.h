// 唯一提供全局变量的单件，所有cpp都应包含此文件。

#pragma once

#ifndef __INTERFACEBOX_H__
#define __INTERFACEBOX_H__

namespace neox
{

namespace client
{
	struct IInterfaceMgr;
	struct IClient;
	struct IFileSystem;
	struct IResFileSystem;
	struct IAsyncLoader;
	struct IEventRecorder;
}

namespace common
{
	struct ILog;
}

namespace utils
{
	struct IUtils;
	struct ITimer;
}

namespace render
{
	struct IRenderer;
	struct ID3DDevice;
}

namespace world
{
	struct IWorld;
}

namespace gui
{
	struct IUIManager;
}

namespace cegui
{
	struct ICEGUI;
}

namespace audio
{
	struct IAudio;
}

namespace physics
{
	struct IPhysics;
}

namespace python
{
	struct IPython;
}

namespace occlusion
{
	struct IOcclusion;
}

namespace terrain
{
	struct ITerrainMgr;
}

namespace video
{
	struct IVideo;
}

namespace collision
{
	struct IColSystem;
	struct IScnDetour;
}

namespace detour
{
	struct IDetourSystem;
}

class InterfaceBox
{
	InterfaceBox();
	~InterfaceBox()
	{}

public:
	void QueryInterfaces(neox::client::IInterfaceMgr *mgr);
	void ClearInterfaces();
	void SetLogChannel(int log_chnl)
	{
		m_log_chnl = log_chnl;
	}

	static InterfaceBox& Instance()
	{
		return m_instance;
	}

public:
	neox::client::IClient *m_client;
	neox::client::IFileSystem *m_file_sys;
	neox::client::IResFileSystem *m_res_file_sys;
	neox::client::IAsyncLoader *m_async_loader;
	neox::client::IEventRecorder *m_event_recorder;
	neox::common::ILog *m_log;
	neox::utils::IUtils *m_utils;
	neox::render::IRenderer *m_renderer;
	neox::render::ID3DDevice *m_d3d_device;
	neox::world::IWorld *m_world;
	neox::gui::IUIManager *m_ui_mgr;
	neox::cegui::ICEGUI *m_cegui;
	neox::audio::IAudio *m_audio;
	neox::physics::IPhysics *m_physics;
	neox::python::IPython *m_python;
	neox::occlusion::IOcclusion *m_occlusion;
	neox::terrain::ITerrainMgr	*m_terrain_mgr;
	neox::video::IVideo *m_video;
	neox::collision::IColSystem *m_col_sys;
	neox::detour::IDetourSystem *m_detour_sys;

	int m_log_chnl;

private:
	static InterfaceBox m_instance;
};

}  // namespace neox

#endif // __INTERFACEBOX_H__