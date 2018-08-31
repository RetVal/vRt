#ifndef _DRIVER_H
#define _DRIVER_H

// disable AMD functions in other platforms
#ifndef AMD_PLATFORM
#undef ENABLE_AMD_INSTRUCTION_SET
#endif

// AMuDe extensions
#ifdef ENABLE_AMD_INSTRUCTION_SET
#extension GL_AMD_shader_trinary_minmax : enable
#extension GL_AMD_texture_gather_bias_lod : enable
#extension GL_AMD_shader_image_load_store_lod : enable
#extension GL_AMD_gcn_shader : enable
//#extension GL_AMD_gpu_shader_half_float : enable
#extension GL_AMD_gpu_shader_half_float_fetch : enable
//#extension GL_AMD_gpu_shader_int16 : enable
#endif

// ARB and ext
#ifdef AMD_PLATFORM
#extension GL_KHX_shader_explicit_arithmetic_types : require
#else
#extension GL_KHX_shader_explicit_arithmetic_types : enable
#endif

#extension GL_EXT_shader_16bit_storage : require
#extension GL_EXT_shader_8bit_storage : enable
#extension GL_ARB_gpu_shader_int64 : enable
#extension GL_EXT_control_flow_attributes : enable
#extension GL_EXT_shader_image_load_formatted : enable

// subgroup operations
#extension GL_KHR_shader_subgroup_basic            : require
#extension GL_KHR_shader_subgroup_vote             : require
#extension GL_KHR_shader_subgroup_ballot           : require
#extension GL_KHR_shader_subgroup_arithmetic       : enable
#extension GL_KHR_shader_subgroup_shuffle          : enable
#extension GL_KHR_shader_subgroup_shuffle_relative : enable
#extension GL_KHR_shader_subgroup_clustered        : enable

// texture extensions
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_EXT_samplerless_texture_functions : enable


// ray tracing options
//#define EXPERIMENTAL_DOF // no dynamic control supported
#define ENABLE_PT_SUNLIGHT
#define DIRECT_LIGHT_ENABLED

//#define SIMPLE_RT_MODE
//#define USE_TRUE_METHOD
//#define DISABLE_REFLECTIONS

// sampling options
//#define MOTION_BLUR
#ifndef SAMPLES_LOCK
#define SAMPLES_LOCK 1
#endif

// enable required GAPI extensions
#ifdef ENABLE_AMD_INSTRUCTION_SET
    #define ENABLE_AMD_INT16
    #define ENABLE_AMD_INT16_CONDITION
    #define USE_16BIT_ADDRESS_SPACE
#endif

#ifndef ENABLE_AMD_INSTRUCTION_SET
    #undef ENABLE_AMD_INT16 // not supported combination
#endif

#ifndef ENABLE_AMD_INT16
    #undef ENABLE_AMD_INT16_CONDITION // required i16
#endif

// Platform-oriented compute
#ifdef EXTEND_LOCAL_GROUPS
    #define WORK_SIZE 1024
#endif

#ifndef WORK_SIZE
    #define WORK_SIZE 64
#endif

#define LOCAL_SIZE_LAYOUT layout(local_size_x=WORK_SIZE)in

#define USE_MORTON_32


#endif
