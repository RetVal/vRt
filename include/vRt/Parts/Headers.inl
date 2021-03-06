#pragma once

//#ifdef OS_WIN
#if (defined(_WIN32) || defined(__MINGW32__) || defined(_MSC_VER_) || defined(__MINGW64__)) 
#define GLFW_EXPOSE_NATIVE_WIN32
#define GLFW_EXPOSE_NATIVE_WGL
#define VK_USE_PLATFORM_WIN32_KHR
#endif

//#ifdef OS_LNX
#ifdef __linux__
#define GLFW_EXPOSE_NATIVE_X11
#define GLFW_EXPOSE_NATIVE_GLX
#define VK_USE_PLATFORM_XLIB_KHR
#endif

// 
#ifdef VULKAN_H_
#define VK_NO_PROTOTYPES
#endif

// if VEZ header detected, mark interop automatically
#ifdef VEZ_H
#define VRT_ENABLE_VEZ_INTEROP
#endif

// include volk.h when possible
#ifndef VULKAN_H_
#ifdef VRT_DONT_USE_VOLK
#include <vulkan/vulkan.h>
#else
#include <vulkan/volk.h>
#endif
#endif

// include VMA when possible
// if no defined VEZ, and not included VMA, include it
#if (!defined(AMD_VULKAN_MEMORY_ALLOCATOR_H) && !defined(VRT_ENABLE_VEZ_INTEROP))
#include <vulkan/vk_mem_alloc.h>
#endif

// include C++17 capable STL
#include <map>
#include <memory>
#include <vector>
#include <functional>
#include <cstdint>
#include <cstddef>
#include <utility>

// include late C++17 string_view support
#ifdef VRT_ENABLE_STRING_VIEW
#include <string_view>
#endif

// empty namespace 
namespace vrt {};
