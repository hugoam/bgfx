--
-- Copyright 2010-2020 Branimir Karadzic. All rights reserved.
-- License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
--

MODULE_DIR = path.getabsolute("../")

newoption {
	trigger = "with-amalgamated",
	description = "Enable amalgamated build.",
}

newoption {
	trigger = "with-sdl",
	description = "Enable SDL entry.",
}

newoption {
	trigger = "with-glfw",
	description = "Enable GLFW entry.",
}

newoption {
	trigger = "with-wayland",
	description = "Use Wayland backend.",
}

newoption {
	trigger = "with-profiler",
	description = "Enable build with intrusive profiler.",
}

newoption {
	trigger = "with-shared-lib",
	description = "Enable building shared library.",
}

newoption {
	trigger = "with-tools",
	description = "Enable building tools.",
}

newoption {
	trigger = "with-combined-examples",
	description = "Enable building examples (combined as single executable).",
}

newoption {
	trigger = "with-examples",
	description = "Enable building examples.",
}

newoption {
	trigger = "with-webgpu",
	description = "Enable webgpu experimental renderer.",
}

newaction {
	trigger = "idl",
	description = "Generate bgfx interface source code",
	execute = function ()

		local gen = require "bgfx-codegen"

		local function generate(tempfile, outputfile, indent)
			local codes = gen.apply(tempfile)
			codes = gen.format(codes, {indent = indent})
			gen.write(codes, outputfile)
			print("Generating: " .. outputfile)
		end

		generate("temp.bgfx.h" ,      "../include/bgfx/c99/bgfx.h", "    ")
		generate("temp.bgfx.idl.inl", "../src/bgfx.idl.inl",        "\t")
		generate("temp.defines.h",    "../include/bgfx/defines.h",  "\t")

		do
			local csgen = require "bindings-cs"
			csgen.write(csgen.gen(), "../bindings/cs/bgfx.cs")
			csgen.write(csgen.gen_dllname(), "../bindings/cs/bgfx_dllname.cs")

			local dgen = require "bindings-d"
			dgen.write(dgen.gen_types(), "../bindings/d/types.d")
			dgen.write(dgen.gen_funcs(), "../bindings/d/funcs.d")

			local csgen = require "bindings-bf"
			csgen.write(csgen.gen(), "../bindings/bf/bgfx.bf")
		end

		os.exit()
	end
}

newaction {
	trigger = "version",
	description = "Generate bgfx version.h",
	execute = function ()

		local f = io.popen("git rev-list --count HEAD")
		local rev = string.match(f:read("*a"), ".*%S")
		f:close()
		f = io.popen("git log --format=format:%H -1")
		local sha1 = f:read("*a")
		f:close()
		io.output(path.join(MODULE_DIR, "src/version.h"))
		io.write("/*\n")
		io.write(" * Copyright 2011-2020 Branimir Karadzic. All rights reserved.\n")
		io.write(" * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause\n")
		io.write(" */\n")
		io.write("\n")
		io.write("/*\n")
		io.write(" *\n")
		io.write(" * AUTO GENERATED! DO NOT EDIT!\n")
		io.write(" *\n")
		io.write(" */\n")
		io.write("\n")
		io.write("#define BGFX_REV_NUMBER " .. rev .. "\n")
		io.write("#define BGFX_REV_SHA1   \"" .. sha1 .. "\"\n")
		io.close()

		os.exit()
	end
}

solution "bgfx"
	configurations {
		"Debug",
		"Release",
	}

	if _ACTION ~= nil and _ACTION:match "^xcode" then
		platforms {
			"Native", -- let xcode decide based on the target output
		}
	else
		platforms {
			"x32",
			"x64",
--			"Xbox360",
			--"Native", -- for targets where bitness is not specified
		}
	end

	language "C++"
	startproject "example-00-helloworld"

BGFX_DIR   = path.getabsolute("..")
BX_DIR     = os.getenv("BX_DIR")
BIMG_DIR   = os.getenv("BIMG_DIR")

local BGFX_BUILD_DIR = path.join(BGFX_DIR, ".build")
local BGFX_THIRD_PARTY_DIR = path.join(BGFX_DIR, "3rdparty")
if not BX_DIR then
	BX_DIR = path.getabsolute(path.join(BGFX_DIR, "../bx"))
end

if not BIMG_DIR then
	BIMG_DIR = path.getabsolute(path.join(BGFX_DIR, "../bimg"))
end

if not os.isdir(BX_DIR) or not os.isdir(BIMG_DIR) then

	if not os.isdir(BX_DIR) then
		print("bx not found at \"" .. BX_DIR .. "\". git clone https://github.com/bkaradzic/bx?")
	end

	if not os.isdir(BIMG_DIR) then
		print("bimg not found at \"" .. BIMG_DIR .. "\". git clone https://github.com/bkaradzic/bimg?")
	end

	print("For more info see: https://bkaradzic.github.io/bgfx/build.html")
	os.exit()
end

if _OPTIONS["with-webgpu"] then
	DAWN_DIR = os.getenv("DAWN_DIR")

	if not DAWN_DIR then
		DAWN_DIR = path.getabsolute(path.join(BGFX_DIR, "../dawn"))
	end

	if not os.isdir(DAWN_DIR) and "wasm*" ~= _OPTIONS["gcc"] then
		print("Dawn not found at \"" .. DAWN_DIR .. "\". git clone https://dawn.googlesource.com/dawn?")

		print("For more info see: https://bkaradzic.github.io/bgfx/build.html")
		--os.exit()
	end

	_OPTIONS["with-windows"] = "10.0"
end

dofile (path.join(BX_DIR, "scripts/toolchain.lua"))
if not toolchain(BGFX_BUILD_DIR, BGFX_THIRD_PARTY_DIR) then
	return -- no action specified
end

function copyLib()
end

if _OPTIONS["with-wayland"] then
	defines { "WL_EGL_PLATFORM=1" }
end

if _OPTIONS["with-sdl"] then
	if os.is("windows") then
		if not os.getenv("SDL2_DIR") then
			print("Set SDL2_DIR enviroment variable.")
		end
	end
end

if _OPTIONS["with-profiler"] then
	defines {
		"ENTRY_CONFIG_PROFILER=1",
		"BGFX_CONFIG_PROFILER=1",
	}
end

function exampleProjectDefaults()

	debugdir (path.join(BGFX_DIR, "examples/runtime"))

	includedirs {
		path.join(BX_DIR,   "include"),
		path.join(BIMG_DIR, "include"),
		path.join(BGFX_DIR, "include"),
		path.join(BGFX_DIR, "3rdparty"),
		path.join(BGFX_DIR, "examples/common"),
		path.join(BGFX_DIR, "src"),
	}

	flags {
		"FatalWarnings",
	}

	links {
		"example-glue",
		"example-common",
		"bgfx",
		"bimg_decode",
		"bimg",
		"bx",
	}

	if _OPTIONS["with-webgpu"] then
		usesWebGPU()
	end

	if _OPTIONS["with-sdl"] then
		defines { "ENTRY_CONFIG_USE_SDL=1" }
		links   { "SDL2" }

		configuration { "linux or freebsd" }
			if _OPTIONS["with-wayland"]  then
				links {
					"wayland-egl",
				}
			end

		configuration { "osx" }
			libdirs { "$(SDL2_DIR)/lib" }

		configuration {}
	end

	if _OPTIONS["with-glfw"] then
		defines { "ENTRY_CONFIG_USE_GLFW=1" }
		links   { "glfw3" }

		configuration { "linux or freebsd" }
			if _OPTIONS["with-wayland"] then
				links {
					"wayland-egl",
				}
			else
				links {
					"Xrandr",
					"Xinerama",
					"Xi",
					"Xxf86vm",
					"Xcursor",
				}
			end

		configuration { "osx" }
			linkoptions {
				"-framework CoreVideo",
				"-framework IOKit",
			}

		configuration {}
	end

	configuration { "vs*", "x32 or x64" }
		linkoptions {
			"/ignore:4199", -- LNK4199: /DELAYLOAD:*.dll ignored; no imports found from *.dll
		}
		links { -- this is needed only for testing with GLES2/3 on Windows with VS2008
			"DelayImp",
		}

	configuration { "vs201*", "x32 or x64" }
		linkoptions { -- this is needed only for testing with GLES2/3 on Windows with VS201x
			"/DELAYLOAD:\"libEGL.dll\"",
			"/DELAYLOAD:\"libGLESv2.dll\"",
		}

	configuration { "mingw*" }
		targetextension ".exe"
		links {
			"gdi32",
			"psapi",
		}

	configuration { "vs20*", "x32 or x64" }
		links {
			"gdi32",
			"psapi",
		}

	configuration { "durango" }
		links {
			"d3d11_x",
			"d3d12_x",
			"combase",
			"kernelx",
		}

	configuration { "winstore*" }
		removelinks {
			"DelayImp",
			"gdi32",
			"psapi"
		}
		links {
			"d3d11",
			"d3d12",
			"dxgi"
		}
		linkoptions {
			"/ignore:4264" -- LNK4264: archiving object file compiled with /ZW into a static library; note that when authoring Windows Runtime types it is not recommended to link with a static library that contains Windows Runtime metadata
		}

	-- WinRT targets need their own output directories or build files stomp over each other
	configuration { "x32", "winstore*" }
		targetdir (path.join(BGFX_BUILD_DIR, "win32_" .. _ACTION, "bin", _name))
		objdir (path.join(BGFX_BUILD_DIR, "win32_" .. _ACTION, "obj", _name))

	configuration { "x64", "winstore*" }
		targetdir (path.join(BGFX_BUILD_DIR, "win64_" .. _ACTION, "bin", _name))
		objdir (path.join(BGFX_BUILD_DIR, "win64_" .. _ACTION, "obj", _name))

	configuration { "ARM", "winstore*" }
		targetdir (path.join(BGFX_BUILD_DIR, "arm_" .. _ACTION, "bin", _name))
		objdir (path.join(BGFX_BUILD_DIR, "arm_" .. _ACTION, "obj", _name))

	configuration { "mingw-clang" }
		kind "ConsoleApp"

	configuration { "android*" }
		kind "ConsoleApp"
		targetextension ".so"
		linkoptions {
			"-shared",
		}
		links {
			"EGL",
			"GLESv2",
		}

	configuration { "wasm*" }
		kind "ConsoleApp"

		linkoptions {
			"-s TOTAL_MEMORY=256MB",
			"-s ALLOW_MEMORY_GROWTH=1",
			--"--preload-file " .. path.join(BGFX_DIR, "examples/runtime") .. "@/",
		}

	configuration { "asmjs", "Release" }
		removeflags {
			"OptimizeSpeed",
		}

		flags {
			"Optimize"
		}

	configuration { "asmjs", "Debug" }
		linkoptions {
			"-g3",
		}
		
	configuration { "linux-* or freebsd" }
		links {
			"X11",
			"GL",
			"pthread",
		}

	configuration { "rpi" }
		links {
			"X11",
			"brcmGLESv2",
			"brcmEGL",
			"bcm_host",
			"vcos",
			"vchiq_arm",
			"pthread",
		}

	configuration { "osx" }
		linkoptions {
			"-framework Cocoa",
			"-framework QuartzCore",
			"-framework OpenGL",
			"-weak_framework Metal",
		}

	configuration { "ios* or tvos*" }
		kind "ConsoleApp"
		linkoptions {
			"-framework CoreFoundation",
			"-framework Foundation",
			"-framework OpenGLES",
			"-framework UIKit",
			"-framework QuartzCore",
			"-weak_framework Metal",
		}

	configuration { "xcode*", "ios" }
		kind "WindowedApp"
		files {
			path.join(BGFX_DIR, "examples/runtime/iOS-Info.plist"),
		}

	configuration { "xcode*", "tvos" }
		kind "WindowedApp"
		files {
			path.join(BGFX_DIR, "examples/runtime/tvOS-Info.plist"),
		}


	configuration { "qnx*" }
		targetextension ""
		links {
			"EGL",
			"GLESv2",
		}

	configuration {}

	strip()
end

function exampleProject(_combined, ...)

	if _combined then

		project ("examples")
			uuid (os.uuid("examples"))
			kind "WindowedApp"

		for _, name in ipairs({...}) do

			files {
				path.join(BGFX_DIR, "examples", name, "**.c"),
				path.join(BGFX_DIR, "examples", name, "**.cpp"),
				path.join(BGFX_DIR, "examples", name, "**.h"),
			}

			removefiles {
				path.join(BGFX_DIR, "examples", name, "**.bin.h"),
			}

		end

		files {
			path.join(BGFX_DIR, "examples/25-c99/helloworld.c"), -- hack for _main_
		}

		exampleProjectDefaults()

	else

		for _, name in ipairs({...}) do
			project ("example-" .. name)
				uuid (os.uuid("example-" .. name))
				kind "WindowedApp"

			files {
				path.join(BGFX_DIR, "examples", name, "**.c"),
				path.join(BGFX_DIR, "examples", name, "**.cpp"),
				path.join(BGFX_DIR, "examples", name, "**.h"),
			}

			removefiles {
				path.join(BGFX_DIR, "examples", name, "**.bin.h"),
			}

			defines {
				"ENTRY_CONFIG_IMPLEMENT_MAIN=1",
			}

			exampleProjectDefaults()
		end
	end

end

dofile "bgfx.lua"

group "libs"

local function userdefines()
	local defines = {}
	local BGFX_CONFIG = os.getenv("BGFX_CONFIG")
	if BGFX_CONFIG then
		for def in BGFX_CONFIG:gmatch "[^%s:]+" do
			table.insert(defines, "BGFX_CONFIG_" .. def)
		end
	end

	return defines
end

BGFX_CONFIG = userdefines()

bgfxProject("", "StaticLib", BGFX_CONFIG)

dofile(path.join(BX_DIR,   "scripts/bx.lua"))
dofile(path.join(BIMG_DIR, "scripts/bimg.lua"))
dofile(path.join(BIMG_DIR, "scripts/bimg_decode.lua"))

if _OPTIONS["with-tools"] then
	dofile(path.join(BIMG_DIR, "scripts/bimg_encode.lua"))
end

if _OPTIONS["with-examples"]
or _OPTIONS["with-combined-examples"]
or _OPTIONS["with-tools"] then
	group "examples"
	dofile "example-common.lua"
end

if _OPTIONS["with-examples"]
or _OPTIONS["with-combined-examples"] then
	group "examples"

	exampleProject(_OPTIONS["with-combined-examples"]
		, "00-helloworld"
		, "01-cubes"
		, "02-metaballs"
		, "03-raymarch"
		, "04-mesh"
		, "05-instancing"
		, "06-bump"
		, "07-callback"
		, "08-update"
		, "09-hdr"
		, "10-font"
		, "11-fontsdf"
		, "12-lod"
		, "13-stencil"
		, "14-shadowvolumes"
		, "15-shadowmaps-simple"
		, "16-shadowmaps"
		--, "17-drawstress"
		, "18-ibl"
		, "19-oit"
		, "20-nanovg"
		, "21-deferred"
		, "22-windows"
		, "23-vectordisplay"
		, "24-nbody"
		, "26-occlusion"
		, "27-terrain"
		, "28-wireframe"
		, "29-debugdraw"
		, "30-picking"
		, "31-rsm"
		, "32-particles"
		, "33-pom"
		, "34-mvs"
		, "35-dynamic"
		, "36-sky"
		, "37-gpudrivenrendering"
		, "38-bloom"
		, "39-assao"
		, "40-svt"
		, "41-tess"
		, "42-bunnylod"
		)

	-- 17-drawstress requires multithreading, does not compile for singlethreaded wasm
--	if platform is not single-threaded then
--		exampleProject(false, "17-drawstress")
--	end

	function addWebAssetsCommon(name, prefix, shaders)
		project(name)
			configuration { "asmjs" }

				for _, shader in ipairs(shaders or {}) do
					local asset = "shaders/spirv/" .. shader .. ".bin"
					linkoptions {
						"--preload-file " .. path.join(BGFX_DIR, "examples/common/" .. asset) .. "@/" .. asset,
					}
				end

			configuration {}
	end

	function addWebAssets(name, shaders, models, textures, assets)
		project(name)
			configuration { "asmjs" }

				for _, shader in ipairs(shaders or {}) do
					local asset = "shaders/spirv/" .. shader .. ".bin"
					linkoptions {
						"--preload-file " .. path.join(BGFX_DIR, "examples/runtime/" .. asset) .. "@/" .. asset,
					}
				end

				for _, model in ipairs(models or {}) do
					local asset = "meshes/" .. model .. ".bin"
					linkoptions {
						"--preload-file " .. path.join(BGFX_DIR, "examples/runtime/" .. asset) .. "@/" .. asset,
					}
				end

				for _, texture in ipairs(textures or {}) do
					local asset = "textures/" .. texture
					linkoptions {
						"--preload-file " .. path.join(BGFX_DIR, "examples/runtime/" .. asset) .. "@/" .. asset,
					}
				end

				for _, asset in ipairs(assets or {}) do
					linkoptions {
						"--preload-file " .. path.join(BGFX_DIR, "examples/runtime/" .. asset) .. "@/" .. asset,
					}
				end

			configuration {}
	end

	addWebAssets("example-01-cubes", { "vs_cubes", "fs_cubes", "fs_cubes_color" })
	addWebAssets("example-03-raymarch", { "vs_raymarching", "fs_raymarching" })
	addWebAssets("example-04-mesh", { "vs_mesh", "fs_mesh" }, { "bunny" })
	addWebAssets("example-05-instancing", { "vs_instancing", "fs_instancing" })
	addWebAssets("example-06-bump", { "vs_bump", "fs_bump" }, {}, { "fieldstone-rgba.png", "fieldstone-n.png" })

	addWebAssets("example-09-hdr", { "vs_hdr_skybox", "fs_hdr_skybox", "vs_hdr_lum", "fs_hdr_lum", "vs_hdr_lumavg", "fs_hdr_lumavg", "vs_hdr_blur",
									 "fs_hdr_blur", "vs_hdr_bright", "fs_hdr_bright", "vs_hdr_mesh", "fs_hdr_mesh", "vs_hdr_tonemap", "fs_hdr_tonemap" },
								   { "bunny" }, { "uffizi.ktx" })

	addWebAssets("example-12-lod",
		{ "vs_tree", "fs_tree" },
		{
			"tree1b_lod0_1",
			"tree1b_lod1_1",
			"tree1b_lod2_1",
			"tree1b_lod0_2",
			"tree1b_lod1_2",
			"tree1b_lod2_2"
		},
		{ "leafs1.dds", "bark1.dds" });

	addWebAssets("example-13-stencil", { "vs_stencil_texture_lighting", "fs_stencil_texture_lighting", "vs_stencil_color_lighting", "fs_stencil_color_lighting",
										 "vs_stencil_color_texture", "fs_stencil_color_texture", "vs_stencil_color", "fs_stencil_color_black", "vs_stencil_texture",
										 "fs_stencil_texture" }, { "bunny", "column" }, { "figure-rgba.dds", "flare.dds", "fieldstone-rgba.dds" })

	addWebAssets("example-14-shadowvolumes",
		{
			"vs_shadowvolume_texture_lighting", "fs_shadowvolume_texture_lighting",
			"vs_shadowvolume_color_lighting",  "fs_shadowvolume_color_lighting",
			"vs_shadowvolume_color_texture", "fs_shadowvolume_color_texture",
			"vs_shadowvolume_texture", "fs_shadowvolume_texture",
			"vs_shadowvolume_svback", "vs_shadowvolume_svside",  "vs_shadowvolume_svfront",
			"fs_shadowvolume_svbackblank", "fs_shadowvolume_svsideblank", "fs_shadowvolume_svfrontblank",
			"fs_shadowvolume_svbackcolor", "fs_shadowvolume_svsidecolor", "fs_shadowvolume_svfrontcolor",
			"fs_shadowvolume_svsidetex",
			"fs_shadowvolume_svbacktex1", "fs_shadowvolume_svbacktex2",
			"fs_shadowvolume_svfronttex1", "fs_shadowvolume_svfronttex2"
		},
		{ "bunny_patched", "bunny_decimated", "column", "platform", "cube" },
		{ "figure-rgba.dds", "flare.dds", "fieldstone-rgba.dds" })

	project "example-14-shadowvolumes"
		configuration { "asmjs" }
			removelinkoptions { "-s TOTAL_MEMORY=256MB" }
			linkoptions       { "-s TOTAL_MEMORY=512MB" }
		configuration {}

	addWebAssets("example-15-shadowmaps-simple", { "vs_sms_shadow_pd", "fs_sms_shadow_pd", "vs_sms_mesh", "fs_sms_mesh_pd", "vs_sms_shadow", "fs_sms_shadow", "vs_sms_mesh", "fs_sms_mesh" },
												 { "bunny", "cube", "hollowcube" })

	addWebAssets("example-16-shadowmaps",
		{
			"vs_shadowmaps_color",         "fs_shadowmaps_color_black",
			"vs_shadowmaps_texture",       "fs_shadowmaps_texture",
			"vs_shadowmaps_color_texture", "fs_shadowmaps_color_texture",

			"vs_shadowmaps_vblur", "fs_shadowmaps_vblur",
			"vs_shadowmaps_hblur", "fs_shadowmaps_hblur",
			"vs_shadowmaps_vblur", "fs_shadowmaps_vblur_vsm",
			"vs_shadowmaps_hblur", "fs_shadowmaps_hblur_vsm",

			"vs_shadowmaps_unpackdepth", "fs_shadowmaps_unpackdepth",
			"vs_shadowmaps_unpackdepth", "fs_shadowmaps_unpackdepth_vsm",

			"vs_shadowmaps_packdepth", "fs_shadowmaps_packdepth",
			"vs_shadowmaps_packdepth", "fs_shadowmaps_packdepth_vsm",

			"vs_shadowmaps_packdepth_linear", "fs_shadowmaps_packdepth_linear",
			"vs_shadowmaps_packdepth_linear", "fs_shadowmaps_packdepth_vsm_linear",

			"vs_shadowmaps_color_lighting", "fs_shadowmaps_color_lighting_hard",
			"vs_shadowmaps_color_lighting", "fs_shadowmaps_color_lighting_pcf",
			"vs_shadowmaps_color_lighting", "fs_shadowmaps_color_lighting_vsm",
			"vs_shadowmaps_color_lighting", "fs_shadowmaps_color_lighting_esm",

			"vs_shadowmaps_color_lighting_linear", "fs_shadowmaps_color_lighting_hard_linear",
			"vs_shadowmaps_color_lighting_linear", "fs_shadowmaps_color_lighting_pcf_linear",
			"vs_shadowmaps_color_lighting_linear", "fs_shadowmaps_color_lighting_vsm_linear",
			"vs_shadowmaps_color_lighting_linear", "fs_shadowmaps_color_lighting_esm_linear",

			"vs_shadowmaps_color_lighting_omni", "fs_shadowmaps_color_lighting_hard_omni",
			"vs_shadowmaps_color_lighting_omni", "fs_shadowmaps_color_lighting_pcf_omni",
			"vs_shadowmaps_color_lighting_omni", "fs_shadowmaps_color_lighting_vsm_omni",
			"vs_shadowmaps_color_lighting_omni", "fs_shadowmaps_color_lighting_esm_omni",

			"vs_shadowmaps_color_lighting_linear_omni", "fs_shadowmaps_color_lighting_hard_linear_omni",
			"vs_shadowmaps_color_lighting_linear_omni", "fs_shadowmaps_color_lighting_pcf_linear_omni",
			"vs_shadowmaps_color_lighting_linear_omni", "fs_shadowmaps_color_lighting_vsm_linear_omni",
			"vs_shadowmaps_color_lighting_linear_omni", "fs_shadowmaps_color_lighting_esm_linear_omni",

			"vs_shadowmaps_color_lighting_csm", "fs_shadowmaps_color_lighting_hard_csm",
			"vs_shadowmaps_color_lighting_csm", "fs_shadowmaps_color_lighting_pcf_csm",
			"vs_shadowmaps_color_lighting_csm", "fs_shadowmaps_color_lighting_vsm_csm",
			"vs_shadowmaps_color_lighting_csm", "fs_shadowmaps_color_lighting_esm_csm",

			"vs_shadowmaps_color_lighting_linear_csm", "fs_shadowmaps_color_lighting_hard_linear_csm",
			"vs_shadowmaps_color_lighting_linear_csm", "fs_shadowmaps_color_lighting_pcf_linear_csm",
			"vs_shadowmaps_color_lighting_linear_csm", "fs_shadowmaps_color_lighting_vsm_linear_csm",
			"vs_shadowmaps_color_lighting_linear_csm", "fs_shadowmaps_color_lighting_esm_linear_csm",
		},
		{ "bunny", "tree", "cube", "hollowcube" },
		{ "figure-rgba.dds", "flare.dds", "fieldstone-rgba.dds" })

	addWebAssets("example-18-ibl",
		{
			"vs_ibl_mesh",   "fs_ibl_mesh",
			"vs_ibl_skybox", "fs_ibl_skybox",
		},
		{ "bunny", "orb" },
		{ "bolonga_lod.dds", "bolonga_irr.dds", "kyoto_lod.dds", "kyoto_irr.dds" })

	addWebAssets("example-19-oit",
		{
			"vs_oit",      "fs_oit",
			"vs_oit",      "fs_oit_wb_separate",
			"vs_oit_blit", "fs_oit_wb_separate_blit",
			"vs_oit",      "fs_oit_wb",
			"vs_oit_blit", "fs_oit_wb_blit"
		})

	addWebAssets("example-20-nanovg",
		{},
		{},
		{},
		{
			"images/image1.jpg",
			"images/image2.jpg",
			"images/image3.jpg",
			"images/image4.jpg",
			"images/image5.jpg",
			"images/image6.jpg",
			"images/image7.jpg",
			"images/image8.jpg",
			"images/image9.jpg",
			"images/image10.jpg",
			"images/image11.jpg",
			"images/image12.jpg",
			"images/blender_icons16.png",
			"font/entypo.ttf",
			"font/roboto-regular.ttf",
			"font/roboto-bold.ttf",
			"font/NotoEmoji-Regular.ttf",
		})

	addWebAssets("example-21-deferred",
		{
			"vs_deferred_geom",
			"vs_deferred_light",
			"vs_deferred_geom",       "fs_deferred_geom",
			"vs_deferred_light",      "fs_deferred_light",
			"vs_deferred_combine",    "fs_deferred_combine",
			"vs_deferred_debug",      "fs_deferred_debug",
			"vs_deferred_debug_line", "fs_deferred_debug_line",
			"vs_deferred_light",      "fs_deferred_light_ta",
			"vs_deferred_light",      "fs_deferred_light_uav",
			"vs_deferred_light",      "fs_deferred_clear_uav",
		},
		{},
		{
			"fieldstone-rgba.dds",
			"fieldstone-n.dds",
		})

	addWebAssets("example-23-vectordisplay",
		{
			"vs_vectordisplay_fb", "fs_vectordisplay_fb",
			"vs_vectordisplay_fb", "fs_vectordisplay_blur",
			"vs_vectordisplay_fb", "fs_vectordisplay_blit"
		});

	addWebAssets("example-24-nbody",
		{
			"vs_particle", "fs_particle",
			"cs_init_instances", "cs_update_instances", "cs_indirect"
		})

	addWebAssets("example-27-terrain",
		{
			"vs_terrain",                "fs_terrain",
			"vs_terrain_height_texture", "fs_terrain"
		})

	addWebAssets("example-28-wireframe",
		{
			"vs_wf_wireframe", "fs_wf_wireframe",
			"vs_wf_mesh",      "fs_wf_mesh"
		},
		{
			"bunny",
			"hollowcube",
			"orb",
		})

	addWebAssets("example-29-debugdraw",
		{})

	addWebAssets("example-30-picking",
		{
			"vs_picking_shaded", "fs_picking_shaded",
			"vs_picking_shaded", "fs_picking_id",
		},
		{
			"orb",
			"column",
			"bunny",
			"cube",
			"tree",
			"hollowcube",
		})

	addWebAssets("example-32-particles",
		{},
		{},
		{ "particle.ktx" })

	addWebAssets("example-35-dynamic",
		{
			"vs_cubes", "fs_cubes"
		})

	addWebAssets("example-36-sky",
		{
			"vs_sky", "fs_sky",
			"vs_sky", "fs_sky_color_banding_fix",
			"vs_sky_landscape", "fs_sky_landscape"
		},
		{
			"test_scene"
		},
		{
			"lightmap.ktx"
		})

	addWebAssets("example-38-bloom",
		{
			"vs_albedo_output", "fs_albedo_output",
			"vs_fullscreen",    "fs_downsample",
			"vs_fullscreen",    "fs_upsample",
			"vs_fullscreen",    "fs_bloom_combine"
		})

	addWebAssets("example-40-svt",
		{
			"vs_vt_generic", "fs_vt_unlit",
			"vs_vt_generic", "fs_vt_mip",
		},
		{},
		{},
		{
			"textures/8k_mars.jpg"
		})

	-- C99 source doesn't compile under WinRT settings
	if not premake.vstudio.iswinrt() then
		exampleProject(false, "25-c99")
	end
end

if _OPTIONS["with-shared-lib"] then
	group "libs"
	bgfxProject("-shared-lib", "SharedLib", BGFX_CONFIG)
end

if _OPTIONS["with-tools"] then
	group "tools"
	dofile "shaderc.lua"
	dofile "texturec.lua"
	dofile "texturev.lua"
	dofile "geometryc.lua"
	dofile "geometryv.lua"
end
