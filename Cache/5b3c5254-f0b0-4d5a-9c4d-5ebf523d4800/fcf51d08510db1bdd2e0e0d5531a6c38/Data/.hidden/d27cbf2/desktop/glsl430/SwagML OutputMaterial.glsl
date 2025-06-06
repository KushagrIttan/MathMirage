#version 430
//#include <required.glsl> // [HACK 4/6/2023] See SCC shader_merger.cpp
//SG_REFLECTION_BEGIN(100)
//attribute vec4 boneData 5
//attribute vec3 blendShape0Pos 6
//attribute vec3 blendShape0Normal 12
//attribute vec3 blendShape1Pos 7
//attribute vec3 blendShape1Normal 13
//attribute vec3 blendShape2Pos 8
//attribute vec3 blendShape2Normal 14
//attribute vec3 blendShape3Pos 9
//attribute vec3 blendShape4Pos 10
//attribute vec3 blendShape5Pos 11
//attribute vec4 position 0
//attribute vec3 normal 1
//attribute vec4 tangent 2
//attribute vec2 texture0 3
//attribute vec2 texture1 4
//attribute vec4 color 18
//attribute vec3 positionNext 15
//attribute vec3 positionPrevious 16
//attribute vec4 strandProperties 17
//sampler sampler camTexSmpSC 2:23
//sampler sampler drivingHairMaskSmpSC 2:24
//sampler sampler flowRelativeSmpSC 2:25
//sampler sampler flowSelectionSmpSC 2:26
//sampler sampler genTexSmpSC 2:27
//sampler sampler intensityTextureSmpSC 2:28
//sampler sampler sc_OITCommonSampler 2:31
//sampler sampler sc_ScreenTextureSmpSC 2:33
//sampler sampler shaderMasksTexSmpSC 2:36
//sampler sampler sourceCropTexSmpSC 2:37
//sampler sampler sourceGarmentMaskSmpSC 2:38
//texture texture2D camTex 2:0:2:23
//texture texture2D drivingHairMask 2:1:2:24
//texture texture2D flowRelative 2:2:2:25
//texture texture2D flowSelection 2:3:2:26
//texture texture2D genTex 2:4:2:27
//texture texture2D intensityTexture 2:5:2:28
//texture texture2D sc_OITAlpha0 2:8:2:31
//texture texture2D sc_OITAlpha1 2:9:2:31
//texture texture2D sc_OITDepthHigh0 2:10:2:31
//texture texture2D sc_OITDepthHigh1 2:11:2:31
//texture texture2D sc_OITDepthLow0 2:12:2:31
//texture texture2D sc_OITDepthLow1 2:13:2:31
//texture texture2D sc_OITFilteredDepthBoundsTexture 2:14:2:31
//texture texture2D sc_OITFrontDepthTexture 2:15:2:31
//texture texture2D sc_ScreenTexture 2:17:2:33
//texture texture2D shaderMasksTex 2:20:2:36
//texture texture2D sourceCropTex 2:21:2:37
//texture texture2D sourceGarmentMask 2:22:2:38
//texture texture2DArray camTexArrSC 2:39:2:23
//texture texture2DArray drivingHairMaskArrSC 2:40:2:24
//texture texture2DArray flowRelativeArrSC 2:41:2:25
//texture texture2DArray flowSelectionArrSC 2:42:2:26
//texture texture2DArray genTexArrSC 2:43:2:27
//texture texture2DArray intensityTextureArrSC 2:44:2:28
//texture texture2DArray sc_ScreenTextureArrSC 2:47:2:33
//texture texture2DArray shaderMasksTexArrSC 2:48:2:36
//texture texture2DArray sourceCropTexArrSC 2:49:2:37
//texture texture2DArray sourceGarmentMaskArrSC 2:50:2:38
//SG_REFLECTION_END
#if defined VERTEX_SHADER
#if 0
NGS_BACKEND_SHADER_FLAGS_BEGIN__
NGS_BACKEND_SHADER_FLAGS_END__
#endif
#ifdef useShaderGridSample
#undef useShaderGridSample
#endif
#define sc_StereoRendering_Disabled 0
#define sc_StereoRendering_InstancedClipped 1
#define sc_StereoRendering_Multiview 2
#ifdef GL_ES
    #define SC_GLES_VERSION_20 2000
    #define SC_GLES_VERSION_30 3000
    #define SC_GLES_VERSION_31 3100
    #define SC_GLES_VERSION_32 3200
#endif
#ifdef VERTEX_SHADER
    #define scOutPos(clipPosition) gl_Position=clipPosition
    #define MAIN main
#endif
#ifdef SC_ENABLE_INSTANCED_RENDERING
    #ifndef sc_EnableInstancing
        #define sc_EnableInstancing 1
    #endif
#endif
#define mod(x,y) (x-y*floor((x+1e-6)/y))
#if defined(GL_ES)&&(__VERSION__<300)&&!defined(GL_OES_standard_derivatives)
#define dFdx(A) (A)
#define dFdy(A) (A)
#define fwidth(A) (A)
#endif
#if __VERSION__<300
#define isinf(x) (x!=0.0&&x*2.0==x ? true : false)
#define isnan(x) (x>0.0||x<0.0||x==0.0 ? false : true)
#endif
#ifdef sc_EnableFeatureLevelES3
    #ifdef sc_EnableStereoClipDistance
        #if defined(GL_APPLE_clip_distance)
            #extension GL_APPLE_clip_distance : require
        #elif defined(GL_EXT_clip_cull_distance)
            #extension GL_EXT_clip_cull_distance : require
        #else
            #error Clip distance is requested but not supported by this device.
        #endif
    #endif
#else
    #ifdef sc_EnableStereoClipDistance
        #error Clip distance is requested but not supported by this device.
    #endif
#endif
#ifdef sc_EnableFeatureLevelES3
    #ifdef VERTEX_SHADER
        #define attribute in
        #define varying out
    #endif
    #ifdef FRAGMENT_SHADER
        #define varying in
    #endif
    #define gl_FragColor sc_FragData0
    #define texture2D texture
    #define texture2DLod textureLod
    #define texture2DLodEXT textureLod
    #define textureCubeLodEXT textureLod
    #define sc_CanUseTextureLod 1
#else
    #ifdef FRAGMENT_SHADER
        #if defined(GL_EXT_shader_texture_lod)
            #extension GL_EXT_shader_texture_lod : require
            #define sc_CanUseTextureLod 1
            #define texture2DLod texture2DLodEXT
        #endif
    #endif
#endif
#if defined(sc_EnableMultiviewStereoRendering)
    #define sc_StereoRenderingMode sc_StereoRendering_Multiview
    #define sc_NumStereoViews 2
    #extension GL_OVR_multiview2 : require
    #ifdef VERTEX_SHADER
        #ifdef sc_EnableInstancingFallback
            #define sc_GlobalInstanceID (sc_FallbackInstanceID*2+gl_InstanceID)
        #else
            #define sc_GlobalInstanceID gl_InstanceID
        #endif
        #define sc_LocalInstanceID sc_GlobalInstanceID
        #define sc_StereoViewID int(gl_ViewID_OVR)
    #endif
#elif defined(sc_EnableInstancedClippedStereoRendering)
    #ifndef sc_EnableInstancing
        #error Instanced-clipped stereo rendering requires enabled instancing.
    #endif
    #ifndef sc_EnableStereoClipDistance
        #define sc_StereoRendering_IsClipDistanceEnabled 0
    #else
        #define sc_StereoRendering_IsClipDistanceEnabled 1
    #endif
    #define sc_StereoRenderingMode sc_StereoRendering_InstancedClipped
    #define sc_NumStereoClipPlanes 1
    #define sc_NumStereoViews 2
    #ifdef VERTEX_SHADER
        #ifdef sc_EnableInstancingFallback
            #define sc_GlobalInstanceID (sc_FallbackInstanceID*2+gl_InstanceID)
        #else
            #define sc_GlobalInstanceID gl_InstanceID
        #endif
        #ifdef sc_EnableFeatureLevelES3
            #define sc_LocalInstanceID (sc_GlobalInstanceID/2)
            #define sc_StereoViewID (sc_GlobalInstanceID%2)
        #else
            #define sc_LocalInstanceID int(sc_GlobalInstanceID/2.0)
            #define sc_StereoViewID int(mod(sc_GlobalInstanceID,2.0))
        #endif
    #endif
#else
    #define sc_StereoRenderingMode sc_StereoRendering_Disabled
#endif
#ifdef VERTEX_SHADER
    #ifdef sc_EnableInstancing
        #ifdef GL_ES
            #if defined(sc_EnableFeatureLevelES2)&&!defined(GL_EXT_draw_instanced)
                #define gl_InstanceID (0)
            #endif
        #else
            #if defined(sc_EnableFeatureLevelES2)&&!defined(GL_EXT_draw_instanced)&&!defined(GL_ARB_draw_instanced)&&!defined(GL_EXT_gpu_shader4)
                #define gl_InstanceID (0)
            #endif
        #endif
        #ifdef GL_ARB_draw_instanced
            #extension GL_ARB_draw_instanced : require
            #define gl_InstanceID gl_InstanceIDARB
        #endif
        #ifdef GL_EXT_draw_instanced
            #extension GL_EXT_draw_instanced : require
            #define gl_InstanceID gl_InstanceIDEXT
        #endif
        #ifndef sc_InstanceID
            #define sc_InstanceID gl_InstanceID
        #endif
        #ifndef sc_GlobalInstanceID
            #ifdef sc_EnableInstancingFallback
                #define sc_GlobalInstanceID (sc_FallbackInstanceID)
                #define sc_LocalInstanceID (sc_FallbackInstanceID)
            #else
                #define sc_GlobalInstanceID gl_InstanceID
                #define sc_LocalInstanceID gl_InstanceID
            #endif
        #endif
    #endif
#endif
#ifdef VERTEX_SHADER
    #if (__VERSION__<300)&&!defined(GL_EXT_gpu_shader4)
        #define gl_VertexID (0)
    #endif
#endif
#ifndef GL_ES
        #extension GL_EXT_gpu_shader4 : enable
    #extension GL_ARB_shader_texture_lod : enable
    #ifndef texture2DLodEXT
        #define texture2DLodEXT texture2DLod
    #endif
    #ifndef sc_CanUseTextureLod
    #define sc_CanUseTextureLod 1
    #endif
    #define precision
    #define lowp
    #define mediump
    #define highp
    #define sc_FragmentPrecision
#endif
#ifdef sc_EnableFeatureLevelES3
    #define sc_CanUseSampler2DArray 1
#endif
#if defined(sc_EnableFeatureLevelES2)&&defined(GL_ES)
    #ifdef FRAGMENT_SHADER
        #ifdef GL_OES_standard_derivatives
            #extension GL_OES_standard_derivatives : require
            #define sc_CanUseStandardDerivatives 1
        #endif
    #endif
    #ifdef GL_EXT_texture_array
        #extension GL_EXT_texture_array : require
        #define sc_CanUseSampler2DArray 1
    #else
        #define sc_CanUseSampler2DArray 0
    #endif
#endif
#ifdef GL_ES
    #ifdef sc_FramebufferFetch
        #if defined(GL_EXT_shader_framebuffer_fetch)
            #extension GL_EXT_shader_framebuffer_fetch : require
        #elif defined(GL_ARM_shader_framebuffer_fetch)
            #extension GL_ARM_shader_framebuffer_fetch : require
        #else
            #error Framebuffer fetch is requested but not supported by this device.
        #endif
    #endif
    #ifdef GL_FRAGMENT_PRECISION_HIGH
        #define sc_FragmentPrecision highp
    #else
        #define sc_FragmentPrecision mediump
    #endif
    #ifdef FRAGMENT_SHADER
        precision highp int;
        precision highp float;
    #endif
#endif
#ifdef VERTEX_SHADER
    #ifdef sc_EnableMultiviewStereoRendering
        layout(num_views=sc_NumStereoViews) in;
    #endif
#endif
#if __VERSION__>100
    #define SC_INT_FALLBACK_FLOAT int
    #define SC_INTERPOLATION_FLAT flat
    #define SC_INTERPOLATION_CENTROID centroid
#else
    #define SC_INT_FALLBACK_FLOAT float
    #define SC_INTERPOLATION_FLAT
    #define SC_INTERPOLATION_CENTROID
#endif
#ifndef sc_NumStereoViews
    #define sc_NumStereoViews 1
#endif
#ifndef sc_CanUseSampler2DArray
    #define sc_CanUseSampler2DArray 0
#endif
    #if __VERSION__==100||defined(SCC_VALIDATION)
        #define sampler2DArray vec2
        #define sampler3D vec3
        #define samplerCube vec4
        vec4 texture3D(vec3 s,vec3 uv)                       { return vec4(0.0); }
        vec4 texture3D(vec3 s,vec3 uv,float bias)           { return vec4(0.0); }
        vec4 texture3DLod(vec3 s,vec3 uv,float bias)        { return vec4(0.0); }
        vec4 texture3DLodEXT(vec3 s,vec3 uv,float lod)      { return vec4(0.0); }
        vec4 texture2DArray(vec2 s,vec3 uv)                  { return vec4(0.0); }
        vec4 texture2DArray(vec2 s,vec3 uv,float bias)      { return vec4(0.0); }
        vec4 texture2DArrayLod(vec2 s,vec3 uv,float lod)    { return vec4(0.0); }
        vec4 texture2DArrayLodEXT(vec2 s,vec3 uv,float lod) { return vec4(0.0); }
        vec4 textureCube(vec4 s,vec3 uv)                     { return vec4(0.0); }
        vec4 textureCube(vec4 s,vec3 uv,float lod)          { return vec4(0.0); }
        vec4 textureCubeLod(vec4 s,vec3 uv,float lod)       { return vec4(0.0); }
        vec4 textureCubeLodEXT(vec4 s,vec3 uv,float lod)    { return vec4(0.0); }
        #if defined(VERTEX_SHADER)||!sc_CanUseTextureLod
            #define texture2DLod(s,uv,lod)      vec4(0.0)
            #define texture2DLodEXT(s,uv,lod)   vec4(0.0)
        #endif
    #elif __VERSION__>=300
        #define texture3D texture
        #define textureCube texture
        #define texture2DArray texture
        #define texture2DLod textureLod
        #define texture3DLod textureLod
        #define texture2DLodEXT textureLod
        #define texture3DLodEXT textureLod
        #define textureCubeLod textureLod
        #define textureCubeLodEXT textureLod
        #define texture2DArrayLod textureLod
        #define texture2DArrayLodEXT textureLod
    #endif
    #ifndef sc_TextureRenderingLayout_Regular
        #define sc_TextureRenderingLayout_Regular 0
        #define sc_TextureRenderingLayout_StereoInstancedClipped 1
        #define sc_TextureRenderingLayout_StereoMultiview 2
    #endif
    #define depthToGlobal   depthScreenToViewSpace
    #define depthToLocal    depthViewToScreenSpace
    #ifndef quantizeUV
        #define quantizeUV sc_QuantizeUV
        #define sc_platformUVFlip sc_PlatformFlipV
        #define sc_PlatformFlipUV sc_PlatformFlipV
    #endif
    #ifndef sc_texture2DLod
        #define sc_texture2DLod sc_InternalTextureLevel
        #define sc_textureLod sc_InternalTextureLevel
        #define sc_textureBias sc_InternalTextureBiasOrLevel
        #define sc_texture sc_InternalTexture
    #endif
struct sc_Vertex_t
{
vec4 position;
vec3 normal;
vec3 tangent;
vec2 texture0;
vec2 texture1;
};
#ifndef sc_StereoRenderingMode
#define sc_StereoRenderingMode 0
#endif
#ifndef sc_StereoViewID
#define sc_StereoViewID 0
#endif
#ifndef sc_RenderingSpace
#define sc_RenderingSpace -1
#endif
#ifndef sc_StereoRendering_IsClipDistanceEnabled
#define sc_StereoRendering_IsClipDistanceEnabled 0
#endif
#ifndef sc_NumStereoViews
#define sc_NumStereoViews 1
#endif
#ifndef sc_SkinBonesCount
#define sc_SkinBonesCount 0
#endif
#ifndef sc_VertexBlending
#define sc_VertexBlending 0
#elif sc_VertexBlending==1
#undef sc_VertexBlending
#define sc_VertexBlending 1
#endif
#ifndef sc_VertexBlendingUseNormals
#define sc_VertexBlendingUseNormals 0
#elif sc_VertexBlendingUseNormals==1
#undef sc_VertexBlendingUseNormals
#define sc_VertexBlendingUseNormals 1
#endif
struct sc_Camera_t
{
vec3 position;
float aspect;
vec2 clipPlanes;
};
#ifndef sc_IsEditor
#define sc_IsEditor 0
#elif sc_IsEditor==1
#undef sc_IsEditor
#define sc_IsEditor 1
#endif
#ifndef SC_DISABLE_FRUSTUM_CULLING
#define SC_DISABLE_FRUSTUM_CULLING 0
#elif SC_DISABLE_FRUSTUM_CULLING==1
#undef SC_DISABLE_FRUSTUM_CULLING
#define SC_DISABLE_FRUSTUM_CULLING 1
#endif
#ifndef sc_DepthBufferMode
#define sc_DepthBufferMode 0
#endif
#ifndef sc_ProjectiveShadowsReceiver
#define sc_ProjectiveShadowsReceiver 0
#elif sc_ProjectiveShadowsReceiver==1
#undef sc_ProjectiveShadowsReceiver
#define sc_ProjectiveShadowsReceiver 1
#endif
#ifndef sc_OITDepthGatherPass
#define sc_OITDepthGatherPass 0
#elif sc_OITDepthGatherPass==1
#undef sc_OITDepthGatherPass
#define sc_OITDepthGatherPass 1
#endif
#ifndef sc_OITCompositingPass
#define sc_OITCompositingPass 0
#elif sc_OITCompositingPass==1
#undef sc_OITCompositingPass
#define sc_OITCompositingPass 1
#endif
#ifndef sc_OITDepthBoundsPass
#define sc_OITDepthBoundsPass 0
#elif sc_OITDepthBoundsPass==1
#undef sc_OITDepthBoundsPass
#define sc_OITDepthBoundsPass 1
#endif
#ifndef UseViewSpaceDepthVariant
#define UseViewSpaceDepthVariant 1
#elif UseViewSpaceDepthVariant==1
#undef UseViewSpaceDepthVariant
#define UseViewSpaceDepthVariant 1
#endif
#ifndef sc_PointLightsCount
#define sc_PointLightsCount 0
#endif
#ifndef sc_DirectionalLightsCount
#define sc_DirectionalLightsCount 0
#endif
#ifndef sc_AmbientLightsCount
#define sc_AmbientLightsCount 0
#endif
struct sc_PointLight_t
{
bool falloffEnabled;
float falloffEndDistance;
float negRcpFalloffEndDistance4;
float angleScale;
float angleOffset;
vec3 direction;
vec3 position;
vec4 color;
};
struct sc_DirectionalLight_t
{
vec3 direction;
vec4 color;
};
struct sc_AmbientLight_t
{
vec3 color;
float intensity;
};
struct sc_SphericalGaussianLight_t
{
vec3 color;
float sharpness;
vec3 axis;
};
struct sc_LightEstimationData_t
{
sc_SphericalGaussianLight_t sg[12];
vec3 ambientLight;
};
uniform vec4 sc_EnvmapDiffuseDims;
uniform vec4 sc_EnvmapSpecularDims;
uniform vec4 sc_ScreenTextureDims;
uniform mat4 sc_ModelMatrix;
uniform mat4 sc_ProjectorMatrix;
uniform vec4 sc_StereoClipPlanes[sc_NumStereoViews];
uniform vec4 sc_BoneMatrices[(sc_SkinBonesCount*3)+1];
uniform mat3 sc_SkinBonesNormalMatrices[sc_SkinBonesCount+1];
uniform vec4 weights0;
uniform vec4 weights1;
uniform mat4 sc_ViewProjectionMatrixArray[sc_NumStereoViews];
uniform mat4 sc_ModelViewProjectionMatrixArray[sc_NumStereoViews];
uniform mat4 sc_ModelViewMatrixArray[sc_NumStereoViews];
uniform sc_Camera_t sc_Camera;
uniform mat4 sc_ProjectionMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ViewMatrixArray[sc_NumStereoViews];
uniform float sc_DisableFrustumCullingMarker;
uniform mat4 sc_ProjectionMatrixArray[sc_NumStereoViews];
uniform mat3 sc_NormalMatrix;
uniform vec2 sc_TAAJitterOffset;
uniform vec4 intensityTextureDims;
uniform int PreviewEnabled;
uniform vec4 camTexDims;
uniform vec4 flowRelativeDims;
uniform vec4 flowSelectionDims;
uniform vec4 sourceCropTexDims;
uniform vec4 sourceGarmentMaskDims;
uniform vec4 shaderMasksTexDims;
uniform vec4 genTexDims;
uniform vec4 drivingHairMaskDims;
uniform int overrideTimeEnabled;
uniform float overrideTimeElapsed;
uniform vec4 sc_Time;
uniform float overrideTimeDelta;
uniform sc_PointLight_t sc_PointLights[sc_PointLightsCount+1];
uniform sc_DirectionalLight_t sc_DirectionalLights[sc_DirectionalLightsCount+1];
uniform sc_AmbientLight_t sc_AmbientLights[sc_AmbientLightsCount+1];
uniform sc_LightEstimationData_t sc_LightEstimationData;
uniform vec4 sc_EnvmapDiffuseSize;
uniform vec4 sc_EnvmapDiffuseView;
uniform vec4 sc_EnvmapSpecularSize;
uniform vec4 sc_EnvmapSpecularView;
uniform vec3 sc_EnvmapRotation;
uniform float sc_EnvmapExposure;
uniform vec3 sc_Sh[9];
uniform float sc_ShIntensity;
uniform vec4 sc_UniformConstants;
uniform vec4 sc_GeometryInfo;
uniform mat4 sc_ModelViewProjectionMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ViewProjectionMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ModelViewMatrixInverseArray[sc_NumStereoViews];
uniform mat3 sc_ViewNormalMatrixArray[sc_NumStereoViews];
uniform mat3 sc_ViewNormalMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ViewMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_PrevFrameViewProjectionMatrixArray[sc_NumStereoViews];
uniform mat4 sc_ModelMatrixInverse;
uniform mat3 sc_NormalMatrixInverse;
uniform mat4 sc_PrevFrameModelMatrix;
uniform mat4 sc_PrevFrameModelMatrixInverse;
uniform vec3 sc_LocalAabbMin;
uniform vec3 sc_LocalAabbMax;
uniform vec3 sc_WorldAabbMin;
uniform vec3 sc_WorldAabbMax;
uniform vec4 sc_WindowToViewportTransform;
uniform vec4 sc_CurrentRenderTargetDims;
uniform float sc_ShadowDensity;
uniform vec4 sc_ShadowColor;
uniform float _sc_GetFramebufferColorInvalidUsageMarker;
uniform float shaderComplexityValue;
uniform vec4 weights2;
uniform int sc_FallbackInstanceID;
uniform float _sc_framebufferFetchMarker;
uniform float strandWidth;
uniform float strandTaper;
uniform vec4 sc_StrandDataMapTextureSize;
uniform float clumpInstanceCount;
uniform float clumpRadius;
uniform float clumpTipScale;
uniform float hairstyleInstanceCount;
uniform float hairstyleNoise;
uniform vec4 sc_ScreenTextureSize;
uniform vec4 sc_ScreenTextureView;
uniform float correctedIntensity;
uniform vec4 intensityTextureSize;
uniform vec4 intensityTextureView;
uniform mat3 intensityTextureTransform;
uniform vec4 intensityTextureUvMinMax;
uniform vec4 intensityTextureBorderColor;
uniform float reflBlurWidth;
uniform float reflBlurMinRough;
uniform float reflBlurMaxRough;
uniform int PreviewNodeID;
uniform float alphaTestThreshold;
uniform vec4 camTexSize;
uniform vec4 camTexView;
uniform mat3 camTexTransform;
uniform vec4 camTexUvMinMax;
uniform vec4 camTexBorderColor;
uniform vec2 cropCenter;
uniform vec2 cropSize;
uniform float flowHalfPx;
uniform vec4 flowRelativeSize;
uniform vec4 flowRelativeView;
uniform mat3 flowRelativeTransform;
uniform vec4 flowRelativeUvMinMax;
uniform vec4 flowRelativeBorderColor;
uniform vec4 flowSelectionSize;
uniform vec4 flowSelectionView;
uniform mat3 flowSelectionTransform;
uniform vec4 flowSelectionUvMinMax;
uniform vec4 flowSelectionBorderColor;
uniform float sx;
uniform float sy;
uniform float dx;
uniform float dy;
uniform vec4 sourceCropTexSize;
uniform vec4 sourceCropTexView;
uniform mat3 sourceCropTexTransform;
uniform vec4 sourceCropTexUvMinMax;
uniform vec4 sourceCropTexBorderColor;
uniform vec4 sourceGarmentMaskSize;
uniform vec4 sourceGarmentMaskView;
uniform mat3 sourceGarmentMaskTransform;
uniform vec4 sourceGarmentMaskUvMinMax;
uniform vec4 sourceGarmentMaskBorderColor;
uniform float shaderMaskHalfPx;
uniform vec4 shaderMasksTexSize;
uniform vec4 shaderMasksTexView;
uniform mat3 shaderMasksTexTransform;
uniform vec4 shaderMasksTexUvMinMax;
uniform vec4 shaderMasksTexBorderColor;
uniform float gridSampAlpha;
uniform vec4 genTexSize;
uniform vec4 genTexView;
uniform mat3 genTexTransform;
uniform vec4 genTexUvMinMax;
uniform vec4 genTexBorderColor;
uniform float genHalfPx;
uniform vec4 drivingHairMaskSize;
uniform vec4 drivingHairMaskView;
uniform mat3 drivingHairMaskTransform;
uniform vec4 drivingHairMaskUvMinMax;
uniform vec4 drivingHairMaskBorderColor;
uniform float segShiftX;
uniform float segRatioX;
uniform float segShiftY;
uniform float segRatioY;
uniform float genAlpha;
uniform bool useShaderGridSample;
out float varClipDistance;
flat out int varStereoViewID;
in vec4 boneData;
in vec3 blendShape0Pos;
in vec3 blendShape0Normal;
in vec3 blendShape1Pos;
in vec3 blendShape1Normal;
in vec3 blendShape2Pos;
in vec3 blendShape2Normal;
in vec3 blendShape3Pos;
in vec3 blendShape4Pos;
in vec3 blendShape5Pos;
in vec4 position;
in vec3 normal;
in vec4 tangent;
in vec2 texture0;
in vec2 texture1;
out vec3 varPos;
out vec3 varNormal;
out vec4 varTangent;
out vec4 varPackedTex;
out vec4 varScreenPos;
out vec2 varScreenTexturePos;
out vec2 varShadowTex;
out float varViewSpaceDepth;
out vec4 varColor;
in vec4 color;
out vec4 PreviewVertexColor;
out float PreviewVertexSaved;
in vec3 positionNext;
in vec3 positionPrevious;
in vec4 strandProperties;
void blendTargetShapeWithNormal(inout sc_Vertex_t v,vec3 position_1,vec3 normal_1,float weight)
{
vec3 l9_0=v.position.xyz+(position_1*weight);
v=sc_Vertex_t(vec4(l9_0.x,l9_0.y,l9_0.z,v.position.w),v.normal,v.tangent,v.texture0,v.texture1);
v.normal+=(normal_1*weight);
}
void sc_GetBoneMatrix(int index,out vec4 m0,out vec4 m1,out vec4 m2)
{
int l9_0=3*index;
m0=sc_BoneMatrices[l9_0];
m1=sc_BoneMatrices[l9_0+1];
m2=sc_BoneMatrices[l9_0+2];
}
vec3 skinVertexPosition(int i,vec4 v)
{
vec3 l9_0;
#if (sc_SkinBonesCount>0)
{
vec4 param_1;
vec4 param_2;
vec4 param_3;
sc_GetBoneMatrix(i,param_1,param_2,param_3);
l9_0=vec3(dot(v,param_1),dot(v,param_2),dot(v,param_3));
}
#else
{
l9_0=v.xyz;
}
#endif
return l9_0;
}
int sc_GetStereoViewIndex()
{
int l9_0;
#if (sc_StereoRenderingMode==0)
{
l9_0=0;
}
#else
{
l9_0=sc_StereoViewID;
}
#endif
return l9_0;
}
void sc_SetClipDistancePlatform(float dstClipDistance)
{
    #if sc_StereoRenderingMode==sc_StereoRendering_InstancedClipped&&sc_StereoRendering_IsClipDistanceEnabled
        gl_ClipDistance[0]=dstClipDistance;
    #endif
}
void main()
{
PreviewVertexColor=vec4(0.5);
PreviewVertexSaved=0.0;
vec4 l9_0;
#if (sc_IsEditor&&SC_DISABLE_FRUSTUM_CULLING)
{
vec4 l9_1=position;
l9_1.x=position.x+sc_DisableFrustumCullingMarker;
l9_0=l9_1;
}
#else
{
l9_0=position;
}
#endif
vec2 l9_2;
vec2 l9_3;
vec3 l9_4;
vec3 l9_5;
vec4 l9_6;
#if (sc_VertexBlending)
{
vec2 l9_7;
vec2 l9_8;
vec3 l9_9;
vec3 l9_10;
vec4 l9_11;
#if (sc_VertexBlendingUseNormals)
{
sc_Vertex_t l9_12=sc_Vertex_t(l9_0,normal,tangent.xyz,texture0,texture1);
blendTargetShapeWithNormal(l9_12,blendShape0Pos,blendShape0Normal,weights0.x);
blendTargetShapeWithNormal(l9_12,blendShape1Pos,blendShape1Normal,weights0.y);
blendTargetShapeWithNormal(l9_12,blendShape2Pos,blendShape2Normal,weights0.z);
l9_11=l9_12.position;
l9_10=l9_12.normal;
l9_9=l9_12.tangent;
l9_8=l9_12.texture0;
l9_7=l9_12.texture1;
}
#else
{
vec3 l9_14=(((((l9_0.xyz+(blendShape0Pos*weights0.x)).xyz+(blendShape1Pos*weights0.y)).xyz+(blendShape2Pos*weights0.z)).xyz+(blendShape3Pos*weights0.w)).xyz+(blendShape4Pos*weights1.x)).xyz+(blendShape5Pos*weights1.y);
l9_11=vec4(l9_14.x,l9_14.y,l9_14.z,l9_0.w);
l9_10=normal;
l9_9=tangent.xyz;
l9_8=texture0;
l9_7=texture1;
}
#endif
l9_6=l9_11;
l9_5=l9_10;
l9_4=l9_9;
l9_3=l9_8;
l9_2=l9_7;
}
#else
{
l9_6=l9_0;
l9_5=normal;
l9_4=tangent.xyz;
l9_3=texture0;
l9_2=texture1;
}
#endif
vec3 l9_15;
vec3 l9_16;
vec4 l9_17;
#if (sc_SkinBonesCount>0)
{
vec4 l9_18;
#if (sc_SkinBonesCount>0)
{
vec4 l9_19=vec4(1.0,fract(boneData.yzw));
vec4 l9_20=l9_19;
l9_20.x=1.0-dot(l9_19.yzw,vec3(1.0));
l9_18=l9_20;
}
#else
{
l9_18=vec4(0.0);
}
#endif
int l9_21=int(boneData.x);
int l9_22=int(boneData.y);
int l9_23=int(boneData.z);
int l9_24=int(boneData.w);
vec3 l9_25=(((skinVertexPosition(l9_21,l9_6)*l9_18.x)+(skinVertexPosition(l9_22,l9_6)*l9_18.y))+(skinVertexPosition(l9_23,l9_6)*l9_18.z))+(skinVertexPosition(l9_24,l9_6)*l9_18.w);
l9_17=vec4(l9_25.x,l9_25.y,l9_25.z,l9_6.w);
l9_16=((((sc_SkinBonesNormalMatrices[l9_21]*l9_5)*l9_18.x)+((sc_SkinBonesNormalMatrices[l9_22]*l9_5)*l9_18.y))+((sc_SkinBonesNormalMatrices[l9_23]*l9_5)*l9_18.z))+((sc_SkinBonesNormalMatrices[l9_24]*l9_5)*l9_18.w);
l9_15=((((sc_SkinBonesNormalMatrices[l9_21]*l9_4)*l9_18.x)+((sc_SkinBonesNormalMatrices[l9_22]*l9_4)*l9_18.y))+((sc_SkinBonesNormalMatrices[l9_23]*l9_4)*l9_18.z))+((sc_SkinBonesNormalMatrices[l9_24]*l9_4)*l9_18.w);
}
#else
{
l9_17=l9_6;
l9_16=l9_5;
l9_15=l9_4;
}
#endif
#if (sc_RenderingSpace==3)
{
varPos=vec3(0.0);
varNormal=l9_16;
varTangent=vec4(l9_15.x,l9_15.y,l9_15.z,varTangent.w);
}
#else
{
#if (sc_RenderingSpace==4)
{
varPos=vec3(0.0);
varNormal=l9_16;
varTangent=vec4(l9_15.x,l9_15.y,l9_15.z,varTangent.w);
}
#else
{
#if (sc_RenderingSpace==2)
{
varPos=l9_17.xyz;
varNormal=l9_16;
varTangent=vec4(l9_15.x,l9_15.y,l9_15.z,varTangent.w);
}
#else
{
#if (sc_RenderingSpace==1)
{
varPos=(sc_ModelMatrix*l9_17).xyz;
varNormal=sc_NormalMatrix*l9_16;
vec3 l9_26=sc_NormalMatrix*l9_15;
varTangent=vec4(l9_26.x,l9_26.y,l9_26.z,varTangent.w);
}
#endif
}
#endif
}
#endif
}
#endif
bool l9_27=PreviewEnabled==1;
vec2 l9_28;
if (l9_27)
{
vec2 l9_29=l9_3;
l9_29.x=1.0-l9_3.x;
l9_28=l9_29;
}
else
{
l9_28=l9_3;
}
varColor=color;
vec3 l9_30=varPos;
vec3 l9_31=varNormal;
vec3 l9_32;
vec3 l9_33;
vec3 l9_34;
if (l9_27)
{
l9_34=varTangent.xyz;
l9_33=varNormal;
l9_32=varPos;
}
else
{
l9_34=varTangent.xyz;
l9_33=l9_31;
l9_32=l9_30;
}
varPos=l9_32;
varNormal=normalize(l9_33);
vec3 l9_35=normalize(l9_34);
varTangent=vec4(l9_35.x,l9_35.y,l9_35.z,varTangent.w);
varTangent.w=tangent.w;
#if (UseViewSpaceDepthVariant&&((sc_OITDepthGatherPass||sc_OITCompositingPass)||sc_OITDepthBoundsPass))
{
vec4 l9_36;
#if (sc_RenderingSpace==3)
{
l9_36=sc_ProjectionMatrixInverseArray[sc_GetStereoViewIndex()]*l9_17;
}
#else
{
vec4 l9_37;
#if (sc_RenderingSpace==2)
{
l9_37=sc_ViewMatrixArray[sc_GetStereoViewIndex()]*l9_17;
}
#else
{
vec4 l9_38;
#if (sc_RenderingSpace==1)
{
l9_38=sc_ModelViewMatrixArray[sc_GetStereoViewIndex()]*l9_17;
}
#else
{
l9_38=l9_17;
}
#endif
l9_37=l9_38;
}
#endif
l9_36=l9_37;
}
#endif
varViewSpaceDepth=-l9_36.z;
}
#endif
vec4 l9_39;
#if (sc_RenderingSpace==3)
{
l9_39=l9_17;
}
#else
{
vec4 l9_40;
#if (sc_RenderingSpace==4)
{
l9_40=(sc_ModelViewMatrixArray[sc_GetStereoViewIndex()]*l9_17)*vec4(1.0/sc_Camera.aspect,1.0,1.0,1.0);
}
#else
{
vec4 l9_41;
#if (sc_RenderingSpace==2)
{
l9_41=sc_ViewProjectionMatrixArray[sc_GetStereoViewIndex()]*vec4(varPos,1.0);
}
#else
{
vec4 l9_42;
#if (sc_RenderingSpace==1)
{
l9_42=sc_ViewProjectionMatrixArray[sc_GetStereoViewIndex()]*vec4(varPos,1.0);
}
#else
{
l9_42=vec4(0.0);
}
#endif
l9_41=l9_42;
}
#endif
l9_40=l9_41;
}
#endif
l9_39=l9_40;
}
#endif
varPackedTex=vec4(l9_28,l9_2);
#if (sc_ProjectiveShadowsReceiver)
{
vec4 l9_43;
#if (sc_RenderingSpace==1)
{
l9_43=sc_ModelMatrix*l9_17;
}
#else
{
l9_43=l9_17;
}
#endif
vec4 l9_44=sc_ProjectorMatrix*l9_43;
varShadowTex=((l9_44.xy/vec2(l9_44.w))*0.5)+vec2(0.5);
}
#endif
vec4 l9_45;
#if (sc_DepthBufferMode==1)
{
vec4 l9_46;
if (sc_ProjectionMatrixArray[sc_GetStereoViewIndex()][2].w!=0.0)
{
vec4 l9_47=l9_39;
l9_47.z=((log2(max(sc_Camera.clipPlanes.x,1.0+l9_39.w))*(2.0/log2(sc_Camera.clipPlanes.y+1.0)))-1.0)*l9_39.w;
l9_46=l9_47;
}
else
{
l9_46=l9_39;
}
l9_45=l9_46;
}
#else
{
l9_45=l9_39;
}
#endif
#if (sc_StereoRenderingMode>0)
{
varStereoViewID=sc_StereoViewID;
}
#endif
#if (sc_StereoRenderingMode==1)
{
float l9_48=dot(l9_45,sc_StereoClipPlanes[sc_StereoViewID]);
#if (sc_StereoRendering_IsClipDistanceEnabled==1)
{
sc_SetClipDistancePlatform(l9_48);
}
#else
{
varClipDistance=l9_48;
}
#endif
}
#endif
gl_Position=l9_45;
}
#elif defined FRAGMENT_SHADER // #if defined VERTEX_SHADER
#if 0
NGS_BACKEND_SHADER_FLAGS_BEGIN__
NGS_BACKEND_SHADER_FLAGS_END__
#endif
#ifdef useShaderGridSample
#undef useShaderGridSample
#endif
#define sc_StereoRendering_Disabled 0
#define sc_StereoRendering_InstancedClipped 1
#define sc_StereoRendering_Multiview 2
#ifdef GL_ES
    #define SC_GLES_VERSION_20 2000
    #define SC_GLES_VERSION_30 3000
    #define SC_GLES_VERSION_31 3100
    #define SC_GLES_VERSION_32 3200
#endif
#ifdef VERTEX_SHADER
    #define scOutPos(clipPosition) gl_Position=clipPosition
    #define MAIN main
#endif
#ifdef SC_ENABLE_INSTANCED_RENDERING
    #ifndef sc_EnableInstancing
        #define sc_EnableInstancing 1
    #endif
#endif
#define mod(x,y) (x-y*floor((x+1e-6)/y))
#if defined(GL_ES)&&(__VERSION__<300)&&!defined(GL_OES_standard_derivatives)
#define dFdx(A) (A)
#define dFdy(A) (A)
#define fwidth(A) (A)
#endif
#if __VERSION__<300
#define isinf(x) (x!=0.0&&x*2.0==x ? true : false)
#define isnan(x) (x>0.0||x<0.0||x==0.0 ? false : true)
#endif
#ifdef sc_EnableFeatureLevelES3
    #ifdef sc_EnableStereoClipDistance
        #if defined(GL_APPLE_clip_distance)
            #extension GL_APPLE_clip_distance : require
        #elif defined(GL_EXT_clip_cull_distance)
            #extension GL_EXT_clip_cull_distance : require
        #else
            #error Clip distance is requested but not supported by this device.
        #endif
    #endif
#else
    #ifdef sc_EnableStereoClipDistance
        #error Clip distance is requested but not supported by this device.
    #endif
#endif
#ifdef sc_EnableFeatureLevelES3
    #ifdef VERTEX_SHADER
        #define attribute in
        #define varying out
    #endif
    #ifdef FRAGMENT_SHADER
        #define varying in
    #endif
    #define gl_FragColor sc_FragData0
    #define texture2D texture
    #define texture2DLod textureLod
    #define texture2DLodEXT textureLod
    #define textureCubeLodEXT textureLod
    #define sc_CanUseTextureLod 1
#else
    #ifdef FRAGMENT_SHADER
        #if defined(GL_EXT_shader_texture_lod)
            #extension GL_EXT_shader_texture_lod : require
            #define sc_CanUseTextureLod 1
            #define texture2DLod texture2DLodEXT
        #endif
    #endif
#endif
#if defined(sc_EnableMultiviewStereoRendering)
    #define sc_StereoRenderingMode sc_StereoRendering_Multiview
    #define sc_NumStereoViews 2
    #extension GL_OVR_multiview2 : require
    #ifdef VERTEX_SHADER
        #ifdef sc_EnableInstancingFallback
            #define sc_GlobalInstanceID (sc_FallbackInstanceID*2+gl_InstanceID)
        #else
            #define sc_GlobalInstanceID gl_InstanceID
        #endif
        #define sc_LocalInstanceID sc_GlobalInstanceID
        #define sc_StereoViewID int(gl_ViewID_OVR)
    #endif
#elif defined(sc_EnableInstancedClippedStereoRendering)
    #ifndef sc_EnableInstancing
        #error Instanced-clipped stereo rendering requires enabled instancing.
    #endif
    #ifndef sc_EnableStereoClipDistance
        #define sc_StereoRendering_IsClipDistanceEnabled 0
    #else
        #define sc_StereoRendering_IsClipDistanceEnabled 1
    #endif
    #define sc_StereoRenderingMode sc_StereoRendering_InstancedClipped
    #define sc_NumStereoClipPlanes 1
    #define sc_NumStereoViews 2
    #ifdef VERTEX_SHADER
        #ifdef sc_EnableInstancingFallback
            #define sc_GlobalInstanceID (sc_FallbackInstanceID*2+gl_InstanceID)
        #else
            #define sc_GlobalInstanceID gl_InstanceID
        #endif
        #ifdef sc_EnableFeatureLevelES3
            #define sc_LocalInstanceID (sc_GlobalInstanceID/2)
            #define sc_StereoViewID (sc_GlobalInstanceID%2)
        #else
            #define sc_LocalInstanceID int(sc_GlobalInstanceID/2.0)
            #define sc_StereoViewID int(mod(sc_GlobalInstanceID,2.0))
        #endif
    #endif
#else
    #define sc_StereoRenderingMode sc_StereoRendering_Disabled
#endif
#ifdef VERTEX_SHADER
    #ifdef sc_EnableInstancing
        #ifdef GL_ES
            #if defined(sc_EnableFeatureLevelES2)&&!defined(GL_EXT_draw_instanced)
                #define gl_InstanceID (0)
            #endif
        #else
            #if defined(sc_EnableFeatureLevelES2)&&!defined(GL_EXT_draw_instanced)&&!defined(GL_ARB_draw_instanced)&&!defined(GL_EXT_gpu_shader4)
                #define gl_InstanceID (0)
            #endif
        #endif
        #ifdef GL_ARB_draw_instanced
            #extension GL_ARB_draw_instanced : require
            #define gl_InstanceID gl_InstanceIDARB
        #endif
        #ifdef GL_EXT_draw_instanced
            #extension GL_EXT_draw_instanced : require
            #define gl_InstanceID gl_InstanceIDEXT
        #endif
        #ifndef sc_InstanceID
            #define sc_InstanceID gl_InstanceID
        #endif
        #ifndef sc_GlobalInstanceID
            #ifdef sc_EnableInstancingFallback
                #define sc_GlobalInstanceID (sc_FallbackInstanceID)
                #define sc_LocalInstanceID (sc_FallbackInstanceID)
            #else
                #define sc_GlobalInstanceID gl_InstanceID
                #define sc_LocalInstanceID gl_InstanceID
            #endif
        #endif
    #endif
#endif
#ifdef VERTEX_SHADER
    #if (__VERSION__<300)&&!defined(GL_EXT_gpu_shader4)
        #define gl_VertexID (0)
    #endif
#endif
#ifndef GL_ES
        #extension GL_EXT_gpu_shader4 : enable
    #extension GL_ARB_shader_texture_lod : enable
    #ifndef texture2DLodEXT
        #define texture2DLodEXT texture2DLod
    #endif
    #ifndef sc_CanUseTextureLod
    #define sc_CanUseTextureLod 1
    #endif
    #define precision
    #define lowp
    #define mediump
    #define highp
    #define sc_FragmentPrecision
#endif
#ifdef sc_EnableFeatureLevelES3
    #define sc_CanUseSampler2DArray 1
#endif
#if defined(sc_EnableFeatureLevelES2)&&defined(GL_ES)
    #ifdef FRAGMENT_SHADER
        #ifdef GL_OES_standard_derivatives
            #extension GL_OES_standard_derivatives : require
            #define sc_CanUseStandardDerivatives 1
        #endif
    #endif
    #ifdef GL_EXT_texture_array
        #extension GL_EXT_texture_array : require
        #define sc_CanUseSampler2DArray 1
    #else
        #define sc_CanUseSampler2DArray 0
    #endif
#endif
#ifdef GL_ES
    #ifdef sc_FramebufferFetch
        #if defined(GL_EXT_shader_framebuffer_fetch)
            #extension GL_EXT_shader_framebuffer_fetch : require
        #elif defined(GL_ARM_shader_framebuffer_fetch)
            #extension GL_ARM_shader_framebuffer_fetch : require
        #else
            #error Framebuffer fetch is requested but not supported by this device.
        #endif
    #endif
    #ifdef GL_FRAGMENT_PRECISION_HIGH
        #define sc_FragmentPrecision highp
    #else
        #define sc_FragmentPrecision mediump
    #endif
    #ifdef FRAGMENT_SHADER
        precision highp int;
        precision highp float;
    #endif
#endif
#ifdef VERTEX_SHADER
    #ifdef sc_EnableMultiviewStereoRendering
        layout(num_views=sc_NumStereoViews) in;
    #endif
#endif
#if __VERSION__>100
    #define SC_INT_FALLBACK_FLOAT int
    #define SC_INTERPOLATION_FLAT flat
    #define SC_INTERPOLATION_CENTROID centroid
#else
    #define SC_INT_FALLBACK_FLOAT float
    #define SC_INTERPOLATION_FLAT
    #define SC_INTERPOLATION_CENTROID
#endif
#ifndef sc_NumStereoViews
    #define sc_NumStereoViews 1
#endif
#ifndef sc_CanUseSampler2DArray
    #define sc_CanUseSampler2DArray 0
#endif
    #if __VERSION__==100||defined(SCC_VALIDATION)
        #define sampler2DArray vec2
        #define sampler3D vec3
        #define samplerCube vec4
        vec4 texture3D(vec3 s,vec3 uv)                       { return vec4(0.0); }
        vec4 texture3D(vec3 s,vec3 uv,float bias)           { return vec4(0.0); }
        vec4 texture3DLod(vec3 s,vec3 uv,float bias)        { return vec4(0.0); }
        vec4 texture3DLodEXT(vec3 s,vec3 uv,float lod)      { return vec4(0.0); }
        vec4 texture2DArray(vec2 s,vec3 uv)                  { return vec4(0.0); }
        vec4 texture2DArray(vec2 s,vec3 uv,float bias)      { return vec4(0.0); }
        vec4 texture2DArrayLod(vec2 s,vec3 uv,float lod)    { return vec4(0.0); }
        vec4 texture2DArrayLodEXT(vec2 s,vec3 uv,float lod) { return vec4(0.0); }
        vec4 textureCube(vec4 s,vec3 uv)                     { return vec4(0.0); }
        vec4 textureCube(vec4 s,vec3 uv,float lod)          { return vec4(0.0); }
        vec4 textureCubeLod(vec4 s,vec3 uv,float lod)       { return vec4(0.0); }
        vec4 textureCubeLodEXT(vec4 s,vec3 uv,float lod)    { return vec4(0.0); }
        #if defined(VERTEX_SHADER)||!sc_CanUseTextureLod
            #define texture2DLod(s,uv,lod)      vec4(0.0)
            #define texture2DLodEXT(s,uv,lod)   vec4(0.0)
        #endif
    #elif __VERSION__>=300
        #define texture3D texture
        #define textureCube texture
        #define texture2DArray texture
        #define texture2DLod textureLod
        #define texture3DLod textureLod
        #define texture2DLodEXT textureLod
        #define texture3DLodEXT textureLod
        #define textureCubeLod textureLod
        #define textureCubeLodEXT textureLod
        #define texture2DArrayLod textureLod
        #define texture2DArrayLodEXT textureLod
    #endif
    #ifndef sc_TextureRenderingLayout_Regular
        #define sc_TextureRenderingLayout_Regular 0
        #define sc_TextureRenderingLayout_StereoInstancedClipped 1
        #define sc_TextureRenderingLayout_StereoMultiview 2
    #endif
    #define depthToGlobal   depthScreenToViewSpace
    #define depthToLocal    depthViewToScreenSpace
    #ifndef quantizeUV
        #define quantizeUV sc_QuantizeUV
        #define sc_platformUVFlip sc_PlatformFlipV
        #define sc_PlatformFlipUV sc_PlatformFlipV
    #endif
    #ifndef sc_texture2DLod
        #define sc_texture2DLod sc_InternalTextureLevel
        #define sc_textureLod sc_InternalTextureLevel
        #define sc_textureBias sc_InternalTextureBiasOrLevel
        #define sc_texture sc_InternalTexture
    #endif
#if sc_ExporterVersion<224
#define MAIN main
#endif
    #ifndef sc_FramebufferFetch
    #define sc_FramebufferFetch 0
    #elif sc_FramebufferFetch==1
    #undef sc_FramebufferFetch
    #define sc_FramebufferFetch 1
    #endif
    #if !defined(GL_ES)&&__VERSION__<420
        #ifdef FRAGMENT_SHADER
            #define sc_FragData0 gl_FragData[0]
            #define sc_FragData1 gl_FragData[1]
            #define sc_FragData2 gl_FragData[2]
            #define sc_FragData3 gl_FragData[3]
        #endif
        mat4 getFragData() { return mat4(vec4(0.0),vec4(0.0),vec4(0.0),vec4(0.0)); }
        #define gl_LastFragData (getFragData())
        #if sc_FramebufferFetch
            #error Framebuffer fetch is requested but not supported by this device.
        #endif
    #elif defined(sc_EnableFeatureLevelES3)
        #if sc_FragDataCount>=1
            #define sc_DeclareFragData0(StorageQualifier) layout(location=0) StorageQualifier sc_FragmentPrecision vec4 sc_FragData0
        #endif
        #if sc_FragDataCount>=2
            #define sc_DeclareFragData1(StorageQualifier) layout(location=1) StorageQualifier sc_FragmentPrecision vec4 sc_FragData1
        #endif
        #if sc_FragDataCount>=3
            #define sc_DeclareFragData2(StorageQualifier) layout(location=2) StorageQualifier sc_FragmentPrecision vec4 sc_FragData2
        #endif
        #if sc_FragDataCount>=4
            #define sc_DeclareFragData3(StorageQualifier) layout(location=3) StorageQualifier sc_FragmentPrecision vec4 sc_FragData3
        #endif
        #ifndef sc_DeclareFragData0
            #define sc_DeclareFragData0(_) const vec4 sc_FragData0=vec4(0.0)
        #endif
        #ifndef sc_DeclareFragData1
            #define sc_DeclareFragData1(_) const vec4 sc_FragData1=vec4(0.0)
        #endif
        #ifndef sc_DeclareFragData2
            #define sc_DeclareFragData2(_) const vec4 sc_FragData2=vec4(0.0)
        #endif
        #ifndef sc_DeclareFragData3
            #define sc_DeclareFragData3(_) const vec4 sc_FragData3=vec4(0.0)
        #endif
        #if sc_FramebufferFetch
            #ifdef GL_EXT_shader_framebuffer_fetch
                sc_DeclareFragData0(inout);
                sc_DeclareFragData1(inout);
                sc_DeclareFragData2(inout);
                sc_DeclareFragData3(inout);
                mediump mat4 getFragData() { return mat4(sc_FragData0,sc_FragData1,sc_FragData2,sc_FragData3); }
                #define gl_LastFragData (getFragData())
            #elif defined(GL_ARM_shader_framebuffer_fetch)
                sc_DeclareFragData0(out);
                sc_DeclareFragData1(out);
                sc_DeclareFragData2(out);
                sc_DeclareFragData3(out);
                mediump mat4 getFragData() { return mat4(gl_LastFragColorARM,vec4(0.0),vec4(0.0),vec4(0.0)); }
                #define gl_LastFragData (getFragData())
            #endif
        #else
            #ifdef sc_EnableFeatureLevelES3
                sc_DeclareFragData0(out);
                sc_DeclareFragData1(out);
                sc_DeclareFragData2(out);
                sc_DeclareFragData3(out);
                mediump mat4 getFragData() { return mat4(vec4(0.0),vec4(0.0),vec4(0.0),vec4(0.0)); }
                #define gl_LastFragData (getFragData())
            #endif
        #endif
    #elif defined(sc_EnableFeatureLevelES2)
        #define sc_FragData0 gl_FragColor
        mediump mat4 getFragData() { return mat4(vec4(0.0),vec4(0.0),vec4(0.0),vec4(0.0)); }
    #else
        #define sc_FragData0 gl_FragColor
        mediump mat4 getFragData() { return mat4(vec4(0.0),vec4(0.0),vec4(0.0),vec4(0.0)); }
    #endif
#ifndef sc_StereoRenderingMode
#define sc_StereoRenderingMode 0
#endif
#ifndef sc_ScreenTextureHasSwappedViews
#define sc_ScreenTextureHasSwappedViews 0
#elif sc_ScreenTextureHasSwappedViews==1
#undef sc_ScreenTextureHasSwappedViews
#define sc_ScreenTextureHasSwappedViews 1
#endif
#ifndef sc_ScreenTextureLayout
#define sc_ScreenTextureLayout 0
#endif
#ifndef sc_NumStereoViews
#define sc_NumStereoViews 1
#endif
#ifndef sc_BlendMode_Normal
#define sc_BlendMode_Normal 0
#elif sc_BlendMode_Normal==1
#undef sc_BlendMode_Normal
#define sc_BlendMode_Normal 1
#endif
#ifndef sc_BlendMode_AlphaToCoverage
#define sc_BlendMode_AlphaToCoverage 0
#elif sc_BlendMode_AlphaToCoverage==1
#undef sc_BlendMode_AlphaToCoverage
#define sc_BlendMode_AlphaToCoverage 1
#endif
#ifndef sc_BlendMode_PremultipliedAlphaHardware
#define sc_BlendMode_PremultipliedAlphaHardware 0
#elif sc_BlendMode_PremultipliedAlphaHardware==1
#undef sc_BlendMode_PremultipliedAlphaHardware
#define sc_BlendMode_PremultipliedAlphaHardware 1
#endif
#ifndef sc_BlendMode_PremultipliedAlphaAuto
#define sc_BlendMode_PremultipliedAlphaAuto 0
#elif sc_BlendMode_PremultipliedAlphaAuto==1
#undef sc_BlendMode_PremultipliedAlphaAuto
#define sc_BlendMode_PremultipliedAlphaAuto 1
#endif
#ifndef sc_BlendMode_PremultipliedAlpha
#define sc_BlendMode_PremultipliedAlpha 0
#elif sc_BlendMode_PremultipliedAlpha==1
#undef sc_BlendMode_PremultipliedAlpha
#define sc_BlendMode_PremultipliedAlpha 1
#endif
#ifndef sc_BlendMode_AddWithAlphaFactor
#define sc_BlendMode_AddWithAlphaFactor 0
#elif sc_BlendMode_AddWithAlphaFactor==1
#undef sc_BlendMode_AddWithAlphaFactor
#define sc_BlendMode_AddWithAlphaFactor 1
#endif
#ifndef sc_BlendMode_AlphaTest
#define sc_BlendMode_AlphaTest 0
#elif sc_BlendMode_AlphaTest==1
#undef sc_BlendMode_AlphaTest
#define sc_BlendMode_AlphaTest 1
#endif
#ifndef sc_BlendMode_Multiply
#define sc_BlendMode_Multiply 0
#elif sc_BlendMode_Multiply==1
#undef sc_BlendMode_Multiply
#define sc_BlendMode_Multiply 1
#endif
#ifndef sc_BlendMode_MultiplyOriginal
#define sc_BlendMode_MultiplyOriginal 0
#elif sc_BlendMode_MultiplyOriginal==1
#undef sc_BlendMode_MultiplyOriginal
#define sc_BlendMode_MultiplyOriginal 1
#endif
#ifndef sc_BlendMode_ColoredGlass
#define sc_BlendMode_ColoredGlass 0
#elif sc_BlendMode_ColoredGlass==1
#undef sc_BlendMode_ColoredGlass
#define sc_BlendMode_ColoredGlass 1
#endif
#ifndef sc_BlendMode_Add
#define sc_BlendMode_Add 0
#elif sc_BlendMode_Add==1
#undef sc_BlendMode_Add
#define sc_BlendMode_Add 1
#endif
#ifndef sc_BlendMode_Screen
#define sc_BlendMode_Screen 0
#elif sc_BlendMode_Screen==1
#undef sc_BlendMode_Screen
#define sc_BlendMode_Screen 1
#endif
#ifndef sc_BlendMode_Min
#define sc_BlendMode_Min 0
#elif sc_BlendMode_Min==1
#undef sc_BlendMode_Min
#define sc_BlendMode_Min 1
#endif
#ifndef sc_BlendMode_Max
#define sc_BlendMode_Max 0
#elif sc_BlendMode_Max==1
#undef sc_BlendMode_Max
#define sc_BlendMode_Max 1
#endif
#ifndef sc_StereoRendering_IsClipDistanceEnabled
#define sc_StereoRendering_IsClipDistanceEnabled 0
#endif
#ifndef sc_ShaderComplexityAnalyzer
#define sc_ShaderComplexityAnalyzer 0
#elif sc_ShaderComplexityAnalyzer==1
#undef sc_ShaderComplexityAnalyzer
#define sc_ShaderComplexityAnalyzer 1
#endif
#ifndef sc_UseFramebufferFetchMarker
#define sc_UseFramebufferFetchMarker 0
#elif sc_UseFramebufferFetchMarker==1
#undef sc_UseFramebufferFetchMarker
#define sc_UseFramebufferFetchMarker 1
#endif
#ifndef sc_FramebufferFetch
#define sc_FramebufferFetch 0
#elif sc_FramebufferFetch==1
#undef sc_FramebufferFetch
#define sc_FramebufferFetch 1
#endif
#ifndef sc_IsEditor
#define sc_IsEditor 0
#elif sc_IsEditor==1
#undef sc_IsEditor
#define sc_IsEditor 1
#endif
#ifndef sc_GetFramebufferColorInvalidUsageMarker
#define sc_GetFramebufferColorInvalidUsageMarker 0
#elif sc_GetFramebufferColorInvalidUsageMarker==1
#undef sc_GetFramebufferColorInvalidUsageMarker
#define sc_GetFramebufferColorInvalidUsageMarker 1
#endif
#ifndef sc_BlendMode_Software
#define sc_BlendMode_Software 0
#elif sc_BlendMode_Software==1
#undef sc_BlendMode_Software
#define sc_BlendMode_Software 1
#endif
#ifndef sc_MotionVectorsPass
#define sc_MotionVectorsPass 0
#elif sc_MotionVectorsPass==1
#undef sc_MotionVectorsPass
#define sc_MotionVectorsPass 1
#endif
#ifndef intensityTextureHasSwappedViews
#define intensityTextureHasSwappedViews 0
#elif intensityTextureHasSwappedViews==1
#undef intensityTextureHasSwappedViews
#define intensityTextureHasSwappedViews 1
#endif
#ifndef intensityTextureLayout
#define intensityTextureLayout 0
#endif
#ifndef BLEND_MODE_REALISTIC
#define BLEND_MODE_REALISTIC 0
#elif BLEND_MODE_REALISTIC==1
#undef BLEND_MODE_REALISTIC
#define BLEND_MODE_REALISTIC 1
#endif
#ifndef BLEND_MODE_FORGRAY
#define BLEND_MODE_FORGRAY 0
#elif BLEND_MODE_FORGRAY==1
#undef BLEND_MODE_FORGRAY
#define BLEND_MODE_FORGRAY 1
#endif
#ifndef BLEND_MODE_NOTBRIGHT
#define BLEND_MODE_NOTBRIGHT 0
#elif BLEND_MODE_NOTBRIGHT==1
#undef BLEND_MODE_NOTBRIGHT
#define BLEND_MODE_NOTBRIGHT 1
#endif
#ifndef BLEND_MODE_DIVISION
#define BLEND_MODE_DIVISION 0
#elif BLEND_MODE_DIVISION==1
#undef BLEND_MODE_DIVISION
#define BLEND_MODE_DIVISION 1
#endif
#ifndef BLEND_MODE_BRIGHT
#define BLEND_MODE_BRIGHT 0
#elif BLEND_MODE_BRIGHT==1
#undef BLEND_MODE_BRIGHT
#define BLEND_MODE_BRIGHT 1
#endif
#ifndef BLEND_MODE_INTENSE
#define BLEND_MODE_INTENSE 0
#elif BLEND_MODE_INTENSE==1
#undef BLEND_MODE_INTENSE
#define BLEND_MODE_INTENSE 1
#endif
#ifndef SC_USE_UV_TRANSFORM_intensityTexture
#define SC_USE_UV_TRANSFORM_intensityTexture 0
#elif SC_USE_UV_TRANSFORM_intensityTexture==1
#undef SC_USE_UV_TRANSFORM_intensityTexture
#define SC_USE_UV_TRANSFORM_intensityTexture 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_intensityTexture
#define SC_SOFTWARE_WRAP_MODE_U_intensityTexture -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_intensityTexture
#define SC_SOFTWARE_WRAP_MODE_V_intensityTexture -1
#endif
#ifndef SC_USE_UV_MIN_MAX_intensityTexture
#define SC_USE_UV_MIN_MAX_intensityTexture 0
#elif SC_USE_UV_MIN_MAX_intensityTexture==1
#undef SC_USE_UV_MIN_MAX_intensityTexture
#define SC_USE_UV_MIN_MAX_intensityTexture 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_intensityTexture
#define SC_USE_CLAMP_TO_BORDER_intensityTexture 0
#elif SC_USE_CLAMP_TO_BORDER_intensityTexture==1
#undef SC_USE_CLAMP_TO_BORDER_intensityTexture
#define SC_USE_CLAMP_TO_BORDER_intensityTexture 1
#endif
#ifndef BLEND_MODE_LIGHTEN
#define BLEND_MODE_LIGHTEN 0
#elif BLEND_MODE_LIGHTEN==1
#undef BLEND_MODE_LIGHTEN
#define BLEND_MODE_LIGHTEN 1
#endif
#ifndef BLEND_MODE_DARKEN
#define BLEND_MODE_DARKEN 0
#elif BLEND_MODE_DARKEN==1
#undef BLEND_MODE_DARKEN
#define BLEND_MODE_DARKEN 1
#endif
#ifndef BLEND_MODE_DIVIDE
#define BLEND_MODE_DIVIDE 0
#elif BLEND_MODE_DIVIDE==1
#undef BLEND_MODE_DIVIDE
#define BLEND_MODE_DIVIDE 1
#endif
#ifndef BLEND_MODE_AVERAGE
#define BLEND_MODE_AVERAGE 0
#elif BLEND_MODE_AVERAGE==1
#undef BLEND_MODE_AVERAGE
#define BLEND_MODE_AVERAGE 1
#endif
#ifndef BLEND_MODE_SUBTRACT
#define BLEND_MODE_SUBTRACT 0
#elif BLEND_MODE_SUBTRACT==1
#undef BLEND_MODE_SUBTRACT
#define BLEND_MODE_SUBTRACT 1
#endif
#ifndef BLEND_MODE_DIFFERENCE
#define BLEND_MODE_DIFFERENCE 0
#elif BLEND_MODE_DIFFERENCE==1
#undef BLEND_MODE_DIFFERENCE
#define BLEND_MODE_DIFFERENCE 1
#endif
#ifndef BLEND_MODE_NEGATION
#define BLEND_MODE_NEGATION 0
#elif BLEND_MODE_NEGATION==1
#undef BLEND_MODE_NEGATION
#define BLEND_MODE_NEGATION 1
#endif
#ifndef BLEND_MODE_EXCLUSION
#define BLEND_MODE_EXCLUSION 0
#elif BLEND_MODE_EXCLUSION==1
#undef BLEND_MODE_EXCLUSION
#define BLEND_MODE_EXCLUSION 1
#endif
#ifndef BLEND_MODE_OVERLAY
#define BLEND_MODE_OVERLAY 0
#elif BLEND_MODE_OVERLAY==1
#undef BLEND_MODE_OVERLAY
#define BLEND_MODE_OVERLAY 1
#endif
#ifndef BLEND_MODE_SOFT_LIGHT
#define BLEND_MODE_SOFT_LIGHT 0
#elif BLEND_MODE_SOFT_LIGHT==1
#undef BLEND_MODE_SOFT_LIGHT
#define BLEND_MODE_SOFT_LIGHT 1
#endif
#ifndef BLEND_MODE_HARD_LIGHT
#define BLEND_MODE_HARD_LIGHT 0
#elif BLEND_MODE_HARD_LIGHT==1
#undef BLEND_MODE_HARD_LIGHT
#define BLEND_MODE_HARD_LIGHT 1
#endif
#ifndef BLEND_MODE_COLOR_DODGE
#define BLEND_MODE_COLOR_DODGE 0
#elif BLEND_MODE_COLOR_DODGE==1
#undef BLEND_MODE_COLOR_DODGE
#define BLEND_MODE_COLOR_DODGE 1
#endif
#ifndef BLEND_MODE_COLOR_BURN
#define BLEND_MODE_COLOR_BURN 0
#elif BLEND_MODE_COLOR_BURN==1
#undef BLEND_MODE_COLOR_BURN
#define BLEND_MODE_COLOR_BURN 1
#endif
#ifndef BLEND_MODE_LINEAR_LIGHT
#define BLEND_MODE_LINEAR_LIGHT 0
#elif BLEND_MODE_LINEAR_LIGHT==1
#undef BLEND_MODE_LINEAR_LIGHT
#define BLEND_MODE_LINEAR_LIGHT 1
#endif
#ifndef BLEND_MODE_VIVID_LIGHT
#define BLEND_MODE_VIVID_LIGHT 0
#elif BLEND_MODE_VIVID_LIGHT==1
#undef BLEND_MODE_VIVID_LIGHT
#define BLEND_MODE_VIVID_LIGHT 1
#endif
#ifndef BLEND_MODE_PIN_LIGHT
#define BLEND_MODE_PIN_LIGHT 0
#elif BLEND_MODE_PIN_LIGHT==1
#undef BLEND_MODE_PIN_LIGHT
#define BLEND_MODE_PIN_LIGHT 1
#endif
#ifndef BLEND_MODE_HARD_MIX
#define BLEND_MODE_HARD_MIX 0
#elif BLEND_MODE_HARD_MIX==1
#undef BLEND_MODE_HARD_MIX
#define BLEND_MODE_HARD_MIX 1
#endif
#ifndef BLEND_MODE_HARD_REFLECT
#define BLEND_MODE_HARD_REFLECT 0
#elif BLEND_MODE_HARD_REFLECT==1
#undef BLEND_MODE_HARD_REFLECT
#define BLEND_MODE_HARD_REFLECT 1
#endif
#ifndef BLEND_MODE_HARD_GLOW
#define BLEND_MODE_HARD_GLOW 0
#elif BLEND_MODE_HARD_GLOW==1
#undef BLEND_MODE_HARD_GLOW
#define BLEND_MODE_HARD_GLOW 1
#endif
#ifndef BLEND_MODE_HARD_PHOENIX
#define BLEND_MODE_HARD_PHOENIX 0
#elif BLEND_MODE_HARD_PHOENIX==1
#undef BLEND_MODE_HARD_PHOENIX
#define BLEND_MODE_HARD_PHOENIX 1
#endif
#ifndef BLEND_MODE_HUE
#define BLEND_MODE_HUE 0
#elif BLEND_MODE_HUE==1
#undef BLEND_MODE_HUE
#define BLEND_MODE_HUE 1
#endif
#ifndef BLEND_MODE_SATURATION
#define BLEND_MODE_SATURATION 0
#elif BLEND_MODE_SATURATION==1
#undef BLEND_MODE_SATURATION
#define BLEND_MODE_SATURATION 1
#endif
#ifndef BLEND_MODE_COLOR
#define BLEND_MODE_COLOR 0
#elif BLEND_MODE_COLOR==1
#undef BLEND_MODE_COLOR
#define BLEND_MODE_COLOR 1
#endif
#ifndef BLEND_MODE_LUMINOSITY
#define BLEND_MODE_LUMINOSITY 0
#elif BLEND_MODE_LUMINOSITY==1
#undef BLEND_MODE_LUMINOSITY
#define BLEND_MODE_LUMINOSITY 1
#endif
#ifndef sc_SkinBonesCount
#define sc_SkinBonesCount 0
#endif
#ifndef UseViewSpaceDepthVariant
#define UseViewSpaceDepthVariant 1
#elif UseViewSpaceDepthVariant==1
#undef UseViewSpaceDepthVariant
#define UseViewSpaceDepthVariant 1
#endif
#ifndef sc_OITDepthGatherPass
#define sc_OITDepthGatherPass 0
#elif sc_OITDepthGatherPass==1
#undef sc_OITDepthGatherPass
#define sc_OITDepthGatherPass 1
#endif
#ifndef sc_OITCompositingPass
#define sc_OITCompositingPass 0
#elif sc_OITCompositingPass==1
#undef sc_OITCompositingPass
#define sc_OITCompositingPass 1
#endif
#ifndef sc_OITDepthBoundsPass
#define sc_OITDepthBoundsPass 0
#elif sc_OITDepthBoundsPass==1
#undef sc_OITDepthBoundsPass
#define sc_OITDepthBoundsPass 1
#endif
#ifndef sc_OITMaxLayers4Plus1
#define sc_OITMaxLayers4Plus1 0
#elif sc_OITMaxLayers4Plus1==1
#undef sc_OITMaxLayers4Plus1
#define sc_OITMaxLayers4Plus1 1
#endif
#ifndef sc_OITMaxLayersVisualizeLayerCount
#define sc_OITMaxLayersVisualizeLayerCount 0
#elif sc_OITMaxLayersVisualizeLayerCount==1
#undef sc_OITMaxLayersVisualizeLayerCount
#define sc_OITMaxLayersVisualizeLayerCount 1
#endif
#ifndef sc_OITMaxLayers8
#define sc_OITMaxLayers8 0
#elif sc_OITMaxLayers8==1
#undef sc_OITMaxLayers8
#define sc_OITMaxLayers8 1
#endif
#ifndef sc_OITFrontLayerPass
#define sc_OITFrontLayerPass 0
#elif sc_OITFrontLayerPass==1
#undef sc_OITFrontLayerPass
#define sc_OITFrontLayerPass 1
#endif
#ifndef sc_OITDepthPrepass
#define sc_OITDepthPrepass 0
#elif sc_OITDepthPrepass==1
#undef sc_OITDepthPrepass
#define sc_OITDepthPrepass 1
#endif
#ifndef ENABLE_STIPPLE_PATTERN_TEST
#define ENABLE_STIPPLE_PATTERN_TEST 0
#elif ENABLE_STIPPLE_PATTERN_TEST==1
#undef ENABLE_STIPPLE_PATTERN_TEST
#define ENABLE_STIPPLE_PATTERN_TEST 1
#endif
#ifndef sc_ProjectiveShadowsCaster
#define sc_ProjectiveShadowsCaster 0
#elif sc_ProjectiveShadowsCaster==1
#undef sc_ProjectiveShadowsCaster
#define sc_ProjectiveShadowsCaster 1
#endif
#ifndef sc_RenderAlphaToColor
#define sc_RenderAlphaToColor 0
#elif sc_RenderAlphaToColor==1
#undef sc_RenderAlphaToColor
#define sc_RenderAlphaToColor 1
#endif
#ifndef sc_BlendMode_Custom
#define sc_BlendMode_Custom 0
#elif sc_BlendMode_Custom==1
#undef sc_BlendMode_Custom
#define sc_BlendMode_Custom 1
#endif
#ifndef camTexHasSwappedViews
#define camTexHasSwappedViews 0
#elif camTexHasSwappedViews==1
#undef camTexHasSwappedViews
#define camTexHasSwappedViews 1
#endif
#ifndef camTexLayout
#define camTexLayout 0
#endif
#ifndef flowRelativeHasSwappedViews
#define flowRelativeHasSwappedViews 0
#elif flowRelativeHasSwappedViews==1
#undef flowRelativeHasSwappedViews
#define flowRelativeHasSwappedViews 1
#endif
#ifndef flowRelativeLayout
#define flowRelativeLayout 0
#endif
#ifndef flowSelectionHasSwappedViews
#define flowSelectionHasSwappedViews 0
#elif flowSelectionHasSwappedViews==1
#undef flowSelectionHasSwappedViews
#define flowSelectionHasSwappedViews 1
#endif
#ifndef flowSelectionLayout
#define flowSelectionLayout 0
#endif
#ifndef sourceCropTexHasSwappedViews
#define sourceCropTexHasSwappedViews 0
#elif sourceCropTexHasSwappedViews==1
#undef sourceCropTexHasSwappedViews
#define sourceCropTexHasSwappedViews 1
#endif
#ifndef sourceCropTexLayout
#define sourceCropTexLayout 0
#endif
#ifndef sourceGarmentMaskHasSwappedViews
#define sourceGarmentMaskHasSwappedViews 0
#elif sourceGarmentMaskHasSwappedViews==1
#undef sourceGarmentMaskHasSwappedViews
#define sourceGarmentMaskHasSwappedViews 1
#endif
#ifndef sourceGarmentMaskLayout
#define sourceGarmentMaskLayout 0
#endif
#ifndef shaderMasksTexHasSwappedViews
#define shaderMasksTexHasSwappedViews 0
#elif shaderMasksTexHasSwappedViews==1
#undef shaderMasksTexHasSwappedViews
#define shaderMasksTexHasSwappedViews 1
#endif
#ifndef shaderMasksTexLayout
#define shaderMasksTexLayout 0
#endif
#ifndef genTexHasSwappedViews
#define genTexHasSwappedViews 0
#elif genTexHasSwappedViews==1
#undef genTexHasSwappedViews
#define genTexHasSwappedViews 1
#endif
#ifndef genTexLayout
#define genTexLayout 0
#endif
#ifndef drivingHairMaskHasSwappedViews
#define drivingHairMaskHasSwappedViews 0
#elif drivingHairMaskHasSwappedViews==1
#undef drivingHairMaskHasSwappedViews
#define drivingHairMaskHasSwappedViews 1
#endif
#ifndef drivingHairMaskLayout
#define drivingHairMaskLayout 0
#endif
#ifndef SC_USE_UV_TRANSFORM_camTex
#define SC_USE_UV_TRANSFORM_camTex 0
#elif SC_USE_UV_TRANSFORM_camTex==1
#undef SC_USE_UV_TRANSFORM_camTex
#define SC_USE_UV_TRANSFORM_camTex 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_camTex
#define SC_SOFTWARE_WRAP_MODE_U_camTex -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_camTex
#define SC_SOFTWARE_WRAP_MODE_V_camTex -1
#endif
#ifndef SC_USE_UV_MIN_MAX_camTex
#define SC_USE_UV_MIN_MAX_camTex 0
#elif SC_USE_UV_MIN_MAX_camTex==1
#undef SC_USE_UV_MIN_MAX_camTex
#define SC_USE_UV_MIN_MAX_camTex 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_camTex
#define SC_USE_CLAMP_TO_BORDER_camTex 0
#elif SC_USE_CLAMP_TO_BORDER_camTex==1
#undef SC_USE_CLAMP_TO_BORDER_camTex
#define SC_USE_CLAMP_TO_BORDER_camTex 1
#endif
#ifndef SC_USE_UV_TRANSFORM_flowRelative
#define SC_USE_UV_TRANSFORM_flowRelative 0
#elif SC_USE_UV_TRANSFORM_flowRelative==1
#undef SC_USE_UV_TRANSFORM_flowRelative
#define SC_USE_UV_TRANSFORM_flowRelative 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_flowRelative
#define SC_SOFTWARE_WRAP_MODE_U_flowRelative -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_flowRelative
#define SC_SOFTWARE_WRAP_MODE_V_flowRelative -1
#endif
#ifndef SC_USE_UV_MIN_MAX_flowRelative
#define SC_USE_UV_MIN_MAX_flowRelative 0
#elif SC_USE_UV_MIN_MAX_flowRelative==1
#undef SC_USE_UV_MIN_MAX_flowRelative
#define SC_USE_UV_MIN_MAX_flowRelative 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_flowRelative
#define SC_USE_CLAMP_TO_BORDER_flowRelative 0
#elif SC_USE_CLAMP_TO_BORDER_flowRelative==1
#undef SC_USE_CLAMP_TO_BORDER_flowRelative
#define SC_USE_CLAMP_TO_BORDER_flowRelative 1
#endif
#ifndef SC_USE_UV_TRANSFORM_flowSelection
#define SC_USE_UV_TRANSFORM_flowSelection 0
#elif SC_USE_UV_TRANSFORM_flowSelection==1
#undef SC_USE_UV_TRANSFORM_flowSelection
#define SC_USE_UV_TRANSFORM_flowSelection 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_flowSelection
#define SC_SOFTWARE_WRAP_MODE_U_flowSelection -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_flowSelection
#define SC_SOFTWARE_WRAP_MODE_V_flowSelection -1
#endif
#ifndef SC_USE_UV_MIN_MAX_flowSelection
#define SC_USE_UV_MIN_MAX_flowSelection 0
#elif SC_USE_UV_MIN_MAX_flowSelection==1
#undef SC_USE_UV_MIN_MAX_flowSelection
#define SC_USE_UV_MIN_MAX_flowSelection 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_flowSelection
#define SC_USE_CLAMP_TO_BORDER_flowSelection 0
#elif SC_USE_CLAMP_TO_BORDER_flowSelection==1
#undef SC_USE_CLAMP_TO_BORDER_flowSelection
#define SC_USE_CLAMP_TO_BORDER_flowSelection 1
#endif
#ifndef SC_USE_UV_TRANSFORM_sourceCropTex
#define SC_USE_UV_TRANSFORM_sourceCropTex 0
#elif SC_USE_UV_TRANSFORM_sourceCropTex==1
#undef SC_USE_UV_TRANSFORM_sourceCropTex
#define SC_USE_UV_TRANSFORM_sourceCropTex 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_sourceCropTex
#define SC_SOFTWARE_WRAP_MODE_U_sourceCropTex -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_sourceCropTex
#define SC_SOFTWARE_WRAP_MODE_V_sourceCropTex -1
#endif
#ifndef SC_USE_UV_MIN_MAX_sourceCropTex
#define SC_USE_UV_MIN_MAX_sourceCropTex 0
#elif SC_USE_UV_MIN_MAX_sourceCropTex==1
#undef SC_USE_UV_MIN_MAX_sourceCropTex
#define SC_USE_UV_MIN_MAX_sourceCropTex 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_sourceCropTex
#define SC_USE_CLAMP_TO_BORDER_sourceCropTex 0
#elif SC_USE_CLAMP_TO_BORDER_sourceCropTex==1
#undef SC_USE_CLAMP_TO_BORDER_sourceCropTex
#define SC_USE_CLAMP_TO_BORDER_sourceCropTex 1
#endif
#ifndef SC_USE_UV_TRANSFORM_sourceGarmentMask
#define SC_USE_UV_TRANSFORM_sourceGarmentMask 0
#elif SC_USE_UV_TRANSFORM_sourceGarmentMask==1
#undef SC_USE_UV_TRANSFORM_sourceGarmentMask
#define SC_USE_UV_TRANSFORM_sourceGarmentMask 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_sourceGarmentMask
#define SC_SOFTWARE_WRAP_MODE_U_sourceGarmentMask -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_sourceGarmentMask
#define SC_SOFTWARE_WRAP_MODE_V_sourceGarmentMask -1
#endif
#ifndef SC_USE_UV_MIN_MAX_sourceGarmentMask
#define SC_USE_UV_MIN_MAX_sourceGarmentMask 0
#elif SC_USE_UV_MIN_MAX_sourceGarmentMask==1
#undef SC_USE_UV_MIN_MAX_sourceGarmentMask
#define SC_USE_UV_MIN_MAX_sourceGarmentMask 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_sourceGarmentMask
#define SC_USE_CLAMP_TO_BORDER_sourceGarmentMask 0
#elif SC_USE_CLAMP_TO_BORDER_sourceGarmentMask==1
#undef SC_USE_CLAMP_TO_BORDER_sourceGarmentMask
#define SC_USE_CLAMP_TO_BORDER_sourceGarmentMask 1
#endif
#ifndef SC_USE_UV_TRANSFORM_shaderMasksTex
#define SC_USE_UV_TRANSFORM_shaderMasksTex 0
#elif SC_USE_UV_TRANSFORM_shaderMasksTex==1
#undef SC_USE_UV_TRANSFORM_shaderMasksTex
#define SC_USE_UV_TRANSFORM_shaderMasksTex 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_shaderMasksTex
#define SC_SOFTWARE_WRAP_MODE_U_shaderMasksTex -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_shaderMasksTex
#define SC_SOFTWARE_WRAP_MODE_V_shaderMasksTex -1
#endif
#ifndef SC_USE_UV_MIN_MAX_shaderMasksTex
#define SC_USE_UV_MIN_MAX_shaderMasksTex 0
#elif SC_USE_UV_MIN_MAX_shaderMasksTex==1
#undef SC_USE_UV_MIN_MAX_shaderMasksTex
#define SC_USE_UV_MIN_MAX_shaderMasksTex 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_shaderMasksTex
#define SC_USE_CLAMP_TO_BORDER_shaderMasksTex 0
#elif SC_USE_CLAMP_TO_BORDER_shaderMasksTex==1
#undef SC_USE_CLAMP_TO_BORDER_shaderMasksTex
#define SC_USE_CLAMP_TO_BORDER_shaderMasksTex 1
#endif
#ifndef SC_USE_UV_TRANSFORM_genTex
#define SC_USE_UV_TRANSFORM_genTex 0
#elif SC_USE_UV_TRANSFORM_genTex==1
#undef SC_USE_UV_TRANSFORM_genTex
#define SC_USE_UV_TRANSFORM_genTex 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_genTex
#define SC_SOFTWARE_WRAP_MODE_U_genTex -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_genTex
#define SC_SOFTWARE_WRAP_MODE_V_genTex -1
#endif
#ifndef SC_USE_UV_MIN_MAX_genTex
#define SC_USE_UV_MIN_MAX_genTex 0
#elif SC_USE_UV_MIN_MAX_genTex==1
#undef SC_USE_UV_MIN_MAX_genTex
#define SC_USE_UV_MIN_MAX_genTex 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_genTex
#define SC_USE_CLAMP_TO_BORDER_genTex 0
#elif SC_USE_CLAMP_TO_BORDER_genTex==1
#undef SC_USE_CLAMP_TO_BORDER_genTex
#define SC_USE_CLAMP_TO_BORDER_genTex 1
#endif
#ifndef SC_USE_UV_TRANSFORM_drivingHairMask
#define SC_USE_UV_TRANSFORM_drivingHairMask 0
#elif SC_USE_UV_TRANSFORM_drivingHairMask==1
#undef SC_USE_UV_TRANSFORM_drivingHairMask
#define SC_USE_UV_TRANSFORM_drivingHairMask 1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_U_drivingHairMask
#define SC_SOFTWARE_WRAP_MODE_U_drivingHairMask -1
#endif
#ifndef SC_SOFTWARE_WRAP_MODE_V_drivingHairMask
#define SC_SOFTWARE_WRAP_MODE_V_drivingHairMask -1
#endif
#ifndef SC_USE_UV_MIN_MAX_drivingHairMask
#define SC_USE_UV_MIN_MAX_drivingHairMask 0
#elif SC_USE_UV_MIN_MAX_drivingHairMask==1
#undef SC_USE_UV_MIN_MAX_drivingHairMask
#define SC_USE_UV_MIN_MAX_drivingHairMask 1
#endif
#ifndef SC_USE_CLAMP_TO_BORDER_drivingHairMask
#define SC_USE_CLAMP_TO_BORDER_drivingHairMask 0
#elif SC_USE_CLAMP_TO_BORDER_drivingHairMask==1
#undef SC_USE_CLAMP_TO_BORDER_drivingHairMask
#define SC_USE_CLAMP_TO_BORDER_drivingHairMask 1
#endif
#ifndef sc_DepthOnly
#define sc_DepthOnly 0
#elif sc_DepthOnly==1
#undef sc_DepthOnly
#define sc_DepthOnly 1
#endif
#ifndef sc_PointLightsCount
#define sc_PointLightsCount 0
#endif
#ifndef sc_DirectionalLightsCount
#define sc_DirectionalLightsCount 0
#endif
#ifndef sc_AmbientLightsCount
#define sc_AmbientLightsCount 0
#endif
struct sc_PointLight_t
{
bool falloffEnabled;
float falloffEndDistance;
float negRcpFalloffEndDistance4;
float angleScale;
float angleOffset;
vec3 direction;
vec3 position;
vec4 color;
};
struct sc_DirectionalLight_t
{
vec3 direction;
vec4 color;
};
struct sc_AmbientLight_t
{
vec3 color;
float intensity;
};
struct sc_SphericalGaussianLight_t
{
vec3 color;
float sharpness;
vec3 axis;
};
struct sc_LightEstimationData_t
{
sc_SphericalGaussianLight_t sg[12];
vec3 ambientLight;
};
struct sc_Camera_t
{
vec3 position;
float aspect;
vec2 clipPlanes;
};
uniform vec4 sc_EnvmapDiffuseDims;
uniform vec4 sc_EnvmapSpecularDims;
uniform vec4 sc_ScreenTextureDims;
uniform vec4 sc_CurrentRenderTargetDims;
uniform mat4 sc_ProjectionMatrixArray[sc_NumStereoViews];
uniform float sc_ShadowDensity;
uniform vec4 sc_ShadowColor;
uniform float shaderComplexityValue;
uniform float _sc_framebufferFetchMarker;
uniform float _sc_GetFramebufferColorInvalidUsageMarker;
uniform mat4 sc_ViewProjectionMatrixArray[sc_NumStereoViews];
uniform mat4 sc_PrevFrameViewProjectionMatrixArray[sc_NumStereoViews];
uniform mat4 sc_PrevFrameModelMatrix;
uniform mat4 sc_ModelMatrixInverse;
uniform vec4 intensityTextureDims;
uniform float correctedIntensity;
uniform mat3 intensityTextureTransform;
uniform vec4 intensityTextureUvMinMax;
uniform vec4 intensityTextureBorderColor;
uniform float alphaTestThreshold;
uniform vec4 camTexDims;
uniform vec4 flowRelativeDims;
uniform vec4 flowSelectionDims;
uniform vec4 sourceCropTexDims;
uniform vec4 sourceGarmentMaskDims;
uniform vec4 shaderMasksTexDims;
uniform vec4 genTexDims;
uniform vec4 drivingHairMaskDims;
uniform mat3 camTexTransform;
uniform vec4 camTexUvMinMax;
uniform vec4 camTexBorderColor;
uniform mat3 flowRelativeTransform;
uniform vec4 flowRelativeUvMinMax;
uniform vec4 flowRelativeBorderColor;
uniform vec4 flowRelativeSize;
uniform mat3 flowSelectionTransform;
uniform vec4 flowSelectionUvMinMax;
uniform vec4 flowSelectionBorderColor;
uniform vec4 flowSelectionSize;
uniform mat3 sourceCropTexTransform;
uniform vec4 sourceCropTexUvMinMax;
uniform vec4 sourceCropTexBorderColor;
uniform mat3 sourceGarmentMaskTransform;
uniform vec4 sourceGarmentMaskUvMinMax;
uniform vec4 sourceGarmentMaskBorderColor;
uniform mat3 shaderMasksTexTransform;
uniform vec4 shaderMasksTexUvMinMax;
uniform vec4 shaderMasksTexBorderColor;
uniform mat3 genTexTransform;
uniform vec4 genTexUvMinMax;
uniform vec4 genTexBorderColor;
uniform vec4 genTexSize;
uniform mat3 drivingHairMaskTransform;
uniform vec4 drivingHairMaskUvMinMax;
uniform vec4 drivingHairMaskBorderColor;
uniform vec4 drivingHairMaskSize;
uniform vec2 cropCenter;
uniform vec2 cropSize;
uniform float flowHalfPx;
uniform float sx;
uniform float sy;
uniform float dx;
uniform float dy;
uniform float shaderMaskHalfPx;
uniform float gridSampAlpha;
uniform float genHalfPx;
uniform float segShiftX;
uniform float segRatioX;
uniform float segShiftY;
uniform float segRatioY;
uniform float genAlpha;
uniform bool useShaderGridSample;
uniform int overrideTimeEnabled;
uniform float overrideTimeElapsed;
uniform vec4 sc_Time;
uniform float overrideTimeDelta;
uniform int PreviewEnabled;
uniform sc_PointLight_t sc_PointLights[sc_PointLightsCount+1];
uniform sc_DirectionalLight_t sc_DirectionalLights[sc_DirectionalLightsCount+1];
uniform sc_AmbientLight_t sc_AmbientLights[sc_AmbientLightsCount+1];
uniform sc_LightEstimationData_t sc_LightEstimationData;
uniform vec4 sc_EnvmapDiffuseSize;
uniform vec4 sc_EnvmapDiffuseView;
uniform vec4 sc_EnvmapSpecularSize;
uniform vec4 sc_EnvmapSpecularView;
uniform vec3 sc_EnvmapRotation;
uniform float sc_EnvmapExposure;
uniform vec3 sc_Sh[9];
uniform float sc_ShIntensity;
uniform vec4 sc_UniformConstants;
uniform vec4 sc_GeometryInfo;
uniform mat4 sc_ModelViewProjectionMatrixArray[sc_NumStereoViews];
uniform mat4 sc_ModelViewProjectionMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ViewProjectionMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ModelViewMatrixArray[sc_NumStereoViews];
uniform mat4 sc_ModelViewMatrixInverseArray[sc_NumStereoViews];
uniform mat3 sc_ViewNormalMatrixArray[sc_NumStereoViews];
uniform mat3 sc_ViewNormalMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ProjectionMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ViewMatrixArray[sc_NumStereoViews];
uniform mat4 sc_ViewMatrixInverseArray[sc_NumStereoViews];
uniform mat4 sc_ModelMatrix;
uniform mat3 sc_NormalMatrix;
uniform mat3 sc_NormalMatrixInverse;
uniform mat4 sc_PrevFrameModelMatrixInverse;
uniform vec3 sc_LocalAabbMin;
uniform vec3 sc_LocalAabbMax;
uniform vec3 sc_WorldAabbMin;
uniform vec3 sc_WorldAabbMax;
uniform vec4 sc_WindowToViewportTransform;
uniform sc_Camera_t sc_Camera;
uniform mat4 sc_ProjectorMatrix;
uniform float sc_DisableFrustumCullingMarker;
uniform vec4 sc_BoneMatrices[(sc_SkinBonesCount*3)+1];
uniform mat3 sc_SkinBonesNormalMatrices[sc_SkinBonesCount+1];
uniform vec4 weights0;
uniform vec4 weights1;
uniform vec4 weights2;
uniform vec4 sc_StereoClipPlanes[sc_NumStereoViews];
uniform int sc_FallbackInstanceID;
uniform vec2 sc_TAAJitterOffset;
uniform float strandWidth;
uniform float strandTaper;
uniform vec4 sc_StrandDataMapTextureSize;
uniform float clumpInstanceCount;
uniform float clumpRadius;
uniform float clumpTipScale;
uniform float hairstyleInstanceCount;
uniform float hairstyleNoise;
uniform vec4 sc_ScreenTextureSize;
uniform vec4 sc_ScreenTextureView;
uniform vec4 intensityTextureSize;
uniform vec4 intensityTextureView;
uniform float reflBlurWidth;
uniform float reflBlurMinRough;
uniform float reflBlurMaxRough;
uniform int PreviewNodeID;
uniform vec4 camTexSize;
uniform vec4 camTexView;
uniform vec4 flowRelativeView;
uniform vec4 flowSelectionView;
uniform vec4 sourceCropTexSize;
uniform vec4 sourceCropTexView;
uniform vec4 sourceGarmentMaskSize;
uniform vec4 sourceGarmentMaskView;
uniform vec4 shaderMasksTexSize;
uniform vec4 shaderMasksTexView;
uniform vec4 genTexView;
uniform vec4 drivingHairMaskView;
uniform sampler2D camTex;
uniform sampler2DArray camTexArrSC;
uniform sampler2D flowRelative;
uniform sampler2DArray flowRelativeArrSC;
uniform sampler2D flowSelection;
uniform sampler2DArray flowSelectionArrSC;
uniform sampler2D sourceCropTex;
uniform sampler2DArray sourceCropTexArrSC;
uniform sampler2D sourceGarmentMask;
uniform sampler2DArray sourceGarmentMaskArrSC;
uniform sampler2D shaderMasksTex;
uniform sampler2DArray shaderMasksTexArrSC;
uniform sampler2D genTex;
uniform sampler2DArray genTexArrSC;
uniform sampler2D drivingHairMask;
uniform sampler2DArray drivingHairMaskArrSC;
uniform sampler2D sc_ScreenTexture;
uniform sampler2DArray sc_ScreenTextureArrSC;
uniform sampler2D intensityTexture;
uniform sampler2DArray intensityTextureArrSC;
uniform sampler2D sc_OITFrontDepthTexture;
uniform sampler2D sc_OITDepthHigh0;
uniform sampler2D sc_OITDepthLow0;
uniform sampler2D sc_OITAlpha0;
uniform sampler2D sc_OITDepthHigh1;
uniform sampler2D sc_OITDepthLow1;
uniform sampler2D sc_OITAlpha1;
uniform sampler2D sc_OITFilteredDepthBoundsTexture;
flat in int varStereoViewID;
in vec2 varShadowTex;
in float varClipDistance;
in float varViewSpaceDepth;
in vec4 PreviewVertexColor;
in float PreviewVertexSaved;
in vec3 varPos;
in vec3 varNormal;
in vec4 varTangent;
in vec4 varPackedTex;
in vec4 varScreenPos;
in vec2 varScreenTexturePos;
in vec4 varColor;
int sc_GetStereoViewIndex()
{
int l9_0;
#if (sc_StereoRenderingMode==0)
{
l9_0=0;
}
#else
{
l9_0=varStereoViewID;
}
#endif
return l9_0;
}
vec2 sc_SamplingCoordsGlobalToView(vec3 uvi,int renderingLayout,int viewIndex)
{
if (renderingLayout==1)
{
uvi.y=((2.0*uvi.y)+float(viewIndex))-1.0;
}
return uvi.xy;
}
vec2 sc_ScreenCoordsGlobalToView(vec2 uv)
{
vec2 l9_0;
#if (sc_StereoRenderingMode==1)
{
l9_0=sc_SamplingCoordsGlobalToView(vec3(uv,0.0),1,sc_GetStereoViewIndex());
}
#else
{
l9_0=uv;
}
#endif
return l9_0;
}
int camTexGetStereoViewIndex()
{
int l9_0;
#if (camTexHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
void sc_SoftwareWrapEarly(inout float uv,int softwareWrapMode)
{
if (softwareWrapMode==1)
{
uv=fract(uv);
}
else
{
if (softwareWrapMode==2)
{
float l9_0=fract(uv);
uv=mix(l9_0,1.0-l9_0,clamp(step(0.25,fract((uv-l9_0)*0.5)),0.0,1.0));
}
}
}
void sc_ClampUV(inout float value,float minValue,float maxValue,bool useClampToBorder,inout float clampToBorderFactor)
{
float l9_0=clamp(value,minValue,maxValue);
float l9_1=step(abs(value-l9_0),9.9999997e-06);
clampToBorderFactor*=(l9_1+((1.0-float(useClampToBorder))*(1.0-l9_1)));
value=l9_0;
}
vec2 sc_TransformUV(vec2 uv,bool useUvTransform,mat3 uvTransform)
{
if (useUvTransform)
{
uv=vec2((uvTransform*vec3(uv,1.0)).xy);
}
return uv;
}
void sc_SoftwareWrapLate(inout float uv,int softwareWrapMode,bool useClampToBorder,inout float clampToBorderFactor)
{
if ((softwareWrapMode==0)||(softwareWrapMode==3))
{
sc_ClampUV(uv,0.0,1.0,useClampToBorder,clampToBorderFactor);
}
}
vec3 sc_SamplingCoordsViewToGlobal(vec2 uv,int renderingLayout,int viewIndex)
{
vec3 l9_0;
if (renderingLayout==0)
{
l9_0=vec3(uv,0.0);
}
else
{
vec3 l9_1;
if (renderingLayout==1)
{
l9_1=vec3(uv.x,(uv.y*0.5)+(0.5-(float(viewIndex)*0.5)),0.0);
}
else
{
l9_1=vec3(uv,float(viewIndex));
}
l9_0=l9_1;
}
return l9_0;
}
vec4 sc_SampleView(vec2 texSize,vec2 uv,int renderingLayout,int viewIndex,float bias,sampler2D texsmp)
{
return texture(texsmp,sc_SamplingCoordsViewToGlobal(uv,renderingLayout,viewIndex).xy,bias);
}
vec4 sc_SampleTextureBiasOrLevel(vec2 samplerDims,int renderingLayout,int viewIndex,vec2 uv,bool useUvTransform,mat3 uvTransform,ivec2 softwareWrapModes,bool useUvMinMax,vec4 uvMinMax,bool useClampToBorder,vec4 borderColor,float biasOrLevel,sampler2D texture_sampler_)
{
bool l9_0=useClampToBorder;
bool l9_1=useUvMinMax;
bool l9_2=l9_0&&(!l9_1);
sc_SoftwareWrapEarly(uv.x,softwareWrapModes.x);
sc_SoftwareWrapEarly(uv.y,softwareWrapModes.y);
float l9_3;
if (useUvMinMax)
{
bool l9_4=useClampToBorder;
bool l9_5;
if (l9_4)
{
l9_5=softwareWrapModes.x==3;
}
else
{
l9_5=l9_4;
}
float param_8=1.0;
sc_ClampUV(uv.x,uvMinMax.x,uvMinMax.z,l9_5,param_8);
float l9_6=param_8;
bool l9_7=useClampToBorder;
bool l9_8;
if (l9_7)
{
l9_8=softwareWrapModes.y==3;
}
else
{
l9_8=l9_7;
}
float param_13=l9_6;
sc_ClampUV(uv.y,uvMinMax.y,uvMinMax.w,l9_8,param_13);
l9_3=param_13;
}
else
{
l9_3=1.0;
}
uv=sc_TransformUV(uv,useUvTransform,uvTransform);
float param_20=l9_3;
sc_SoftwareWrapLate(uv.x,softwareWrapModes.x,l9_2,param_20);
sc_SoftwareWrapLate(uv.y,softwareWrapModes.y,l9_2,param_20);
float l9_9=param_20;
vec4 l9_10=sc_SampleView(samplerDims,uv,renderingLayout,viewIndex,biasOrLevel,texture_sampler_);
vec4 l9_11;
if (useClampToBorder)
{
l9_11=mix(borderColor,l9_10,vec4(l9_9));
}
else
{
l9_11=l9_10;
}
return l9_11;
}
vec4 sc_SampleView(vec2 texSize,vec2 uv,int renderingLayout,int viewIndex,float bias,sampler2DArray texsmp)
{
return texture(texsmp,sc_SamplingCoordsViewToGlobal(uv,renderingLayout,viewIndex),bias);
}
vec4 sc_SampleTextureBiasOrLevel(vec2 samplerDims,int renderingLayout,int viewIndex,vec2 uv,bool useUvTransform,mat3 uvTransform,ivec2 softwareWrapModes,bool useUvMinMax,vec4 uvMinMax,bool useClampToBorder,vec4 borderColor,float biasOrLevel,sampler2DArray texture_sampler_)
{
bool l9_0=useClampToBorder;
bool l9_1=useUvMinMax;
bool l9_2=l9_0&&(!l9_1);
sc_SoftwareWrapEarly(uv.x,softwareWrapModes.x);
sc_SoftwareWrapEarly(uv.y,softwareWrapModes.y);
float l9_3;
if (useUvMinMax)
{
bool l9_4=useClampToBorder;
bool l9_5;
if (l9_4)
{
l9_5=softwareWrapModes.x==3;
}
else
{
l9_5=l9_4;
}
float param_8=1.0;
sc_ClampUV(uv.x,uvMinMax.x,uvMinMax.z,l9_5,param_8);
float l9_6=param_8;
bool l9_7=useClampToBorder;
bool l9_8;
if (l9_7)
{
l9_8=softwareWrapModes.y==3;
}
else
{
l9_8=l9_7;
}
float param_13=l9_6;
sc_ClampUV(uv.y,uvMinMax.y,uvMinMax.w,l9_8,param_13);
l9_3=param_13;
}
else
{
l9_3=1.0;
}
uv=sc_TransformUV(uv,useUvTransform,uvTransform);
float param_20=l9_3;
sc_SoftwareWrapLate(uv.x,softwareWrapModes.x,l9_2,param_20);
sc_SoftwareWrapLate(uv.y,softwareWrapModes.y,l9_2,param_20);
float l9_9=param_20;
vec4 l9_10=sc_SampleView(samplerDims,uv,renderingLayout,viewIndex,biasOrLevel,texture_sampler_);
vec4 l9_11;
if (useClampToBorder)
{
l9_11=mix(borderColor,l9_10,vec4(l9_9));
}
else
{
l9_11=l9_10;
}
return l9_11;
}
int flowRelativeGetStereoViewIndex()
{
int l9_0;
#if (flowRelativeHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
vec4 N52_flowrelativeTex_sample(vec2 coords)
{
vec4 l9_0;
#if (flowRelativeLayout==2)
{
l9_0=sc_SampleTextureBiasOrLevel(flowRelativeDims.xy,flowRelativeLayout,flowRelativeGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_flowRelative)!=0),flowRelativeTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_flowRelative,SC_SOFTWARE_WRAP_MODE_V_flowRelative),(int(SC_USE_UV_MIN_MAX_flowRelative)!=0),flowRelativeUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_flowRelative)!=0),flowRelativeBorderColor,0.0,flowRelativeArrSC);
}
#else
{
l9_0=sc_SampleTextureBiasOrLevel(flowRelativeDims.xy,flowRelativeLayout,flowRelativeGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_flowRelative)!=0),flowRelativeTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_flowRelative,SC_SOFTWARE_WRAP_MODE_V_flowRelative),(int(SC_USE_UV_MIN_MAX_flowRelative)!=0),flowRelativeUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_flowRelative)!=0),flowRelativeBorderColor,0.0,flowRelative);
}
#endif
return l9_0;
}
vec4 N52_sampleBiLinearRelative(vec2 uv)
{
vec2 l9_0=vec2(1.0)/flowRelativeSize.xy;
vec2 l9_1=(uv*flowRelativeSize.xy)+vec2(0.5);
vec2 l9_2=fract(l9_1);
vec2 l9_3=(floor(l9_1)/flowRelativeSize.xy)-(l9_0/vec2(2.0));
vec4 l9_4=vec4(l9_2.x);
return mix(mix(N52_flowrelativeTex_sample(l9_3),N52_flowrelativeTex_sample(l9_3+vec2(l9_0.x,0.0)),l9_4),mix(N52_flowrelativeTex_sample(l9_3+vec2(0.0,l9_0.y)),N52_flowrelativeTex_sample(l9_3+l9_0),l9_4),vec4(l9_2.y));
}
int flowSelectionGetStereoViewIndex()
{
int l9_0;
#if (flowSelectionHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
vec4 N52_flowselectionTex_sample(vec2 coords)
{
vec4 l9_0;
#if (flowSelectionLayout==2)
{
l9_0=sc_SampleTextureBiasOrLevel(flowSelectionDims.xy,flowSelectionLayout,flowSelectionGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_flowSelection)!=0),flowSelectionTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_flowSelection,SC_SOFTWARE_WRAP_MODE_V_flowSelection),(int(SC_USE_UV_MIN_MAX_flowSelection)!=0),flowSelectionUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_flowSelection)!=0),flowSelectionBorderColor,0.0,flowSelectionArrSC);
}
#else
{
l9_0=sc_SampleTextureBiasOrLevel(flowSelectionDims.xy,flowSelectionLayout,flowSelectionGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_flowSelection)!=0),flowSelectionTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_flowSelection,SC_SOFTWARE_WRAP_MODE_V_flowSelection),(int(SC_USE_UV_MIN_MAX_flowSelection)!=0),flowSelectionUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_flowSelection)!=0),flowSelectionBorderColor,0.0,flowSelection);
}
#endif
return l9_0;
}
vec4 N52_sampleBiLinearSelection(vec2 uv)
{
vec2 l9_0=vec2(1.0)/flowSelectionSize.xy;
vec2 l9_1=(uv*flowSelectionSize.xy)+vec2(0.5);
vec2 l9_2=fract(l9_1);
vec2 l9_3=(floor(l9_1)/flowSelectionSize.xy)-(l9_0/vec2(2.0));
vec4 l9_4=vec4(l9_2.x);
return mix(mix(N52_flowselectionTex_sample(l9_3),N52_flowselectionTex_sample(l9_3+vec2(l9_0.x,0.0)),l9_4),mix(N52_flowselectionTex_sample(l9_3+vec2(0.0,l9_0.y)),N52_flowselectionTex_sample(l9_3+l9_0),l9_4),vec4(l9_2.y));
}
int sourceCropTexGetStereoViewIndex()
{
int l9_0;
#if (sourceCropTexHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
int sourceGarmentMaskGetStereoViewIndex()
{
int l9_0;
#if (sourceGarmentMaskHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
int shaderMasksTexGetStereoViewIndex()
{
int l9_0;
#if (shaderMasksTexHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
int genTexGetStereoViewIndex()
{
int l9_0;
#if (genTexHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
vec4 N52_generatedTex_sample(vec2 coords)
{
vec4 l9_0;
#if (genTexLayout==2)
{
l9_0=sc_SampleTextureBiasOrLevel(genTexDims.xy,genTexLayout,genTexGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_genTex)!=0),genTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_genTex,SC_SOFTWARE_WRAP_MODE_V_genTex),(int(SC_USE_UV_MIN_MAX_genTex)!=0),genTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_genTex)!=0),genTexBorderColor,0.0,genTexArrSC);
}
#else
{
l9_0=sc_SampleTextureBiasOrLevel(genTexDims.xy,genTexLayout,genTexGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_genTex)!=0),genTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_genTex,SC_SOFTWARE_WRAP_MODE_V_genTex),(int(SC_USE_UV_MIN_MAX_genTex)!=0),genTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_genTex)!=0),genTexBorderColor,0.0,genTex);
}
#endif
return l9_0;
}
int drivingHairMaskGetStereoViewIndex()
{
int l9_0;
#if (drivingHairMaskHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
vec4 N52_drivinghairTex_sample(vec2 coords)
{
vec4 l9_0;
#if (drivingHairMaskLayout==2)
{
l9_0=sc_SampleTextureBiasOrLevel(drivingHairMaskDims.xy,drivingHairMaskLayout,drivingHairMaskGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_drivingHairMask)!=0),drivingHairMaskTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_drivingHairMask,SC_SOFTWARE_WRAP_MODE_V_drivingHairMask),(int(SC_USE_UV_MIN_MAX_drivingHairMask)!=0),drivingHairMaskUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_drivingHairMask)!=0),drivingHairMaskBorderColor,0.0,drivingHairMaskArrSC);
}
#else
{
l9_0=sc_SampleTextureBiasOrLevel(drivingHairMaskDims.xy,drivingHairMaskLayout,drivingHairMaskGetStereoViewIndex(),coords,(int(SC_USE_UV_TRANSFORM_drivingHairMask)!=0),drivingHairMaskTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_drivingHairMask,SC_SOFTWARE_WRAP_MODE_V_drivingHairMask),(int(SC_USE_UV_MIN_MAX_drivingHairMask)!=0),drivingHairMaskUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_drivingHairMask)!=0),drivingHairMaskBorderColor,0.0,drivingHairMask);
}
#endif
return l9_0;
}
vec4 sc_readFragData0_Platform()
{
    return getFragData()[0];
}
int intensityTextureGetStereoViewIndex()
{
int l9_0;
#if (intensityTextureHasSwappedViews)
{
l9_0=1-sc_GetStereoViewIndex();
}
#else
{
l9_0=sc_GetStereoViewIndex();
}
#endif
return l9_0;
}
float transformSingleColor(float original,float intMap,float target)
{
#if ((BLEND_MODE_REALISTIC||BLEND_MODE_FORGRAY)||BLEND_MODE_NOTBRIGHT)
{
return original/pow(1.0-target,intMap);
}
#else
{
#if (BLEND_MODE_DIVISION)
{
return original/(1.0-target);
}
#else
{
#if (BLEND_MODE_BRIGHT)
{
return original/pow(1.0-target,2.0-(2.0*original));
}
#endif
}
#endif
}
#endif
return 0.0;
}
vec3 RGBtoHCV(vec3 rgb)
{
vec4 l9_0;
if (rgb.y<rgb.z)
{
l9_0=vec4(rgb.zy,-1.0,0.66666669);
}
else
{
l9_0=vec4(rgb.yz,0.0,-0.33333334);
}
vec4 l9_1;
if (rgb.x<l9_0.x)
{
l9_1=vec4(l9_0.xyw,rgb.x);
}
else
{
l9_1=vec4(rgb.x,l9_0.yzx);
}
float l9_2=l9_1.x-min(l9_1.w,l9_1.y);
return vec3(abs(((l9_1.w-l9_1.y)/((6.0*l9_2)+1e-07))+l9_1.z),l9_2,l9_1.x);
}
vec3 RGBToHSL(vec3 rgb)
{
vec3 l9_0=RGBtoHCV(rgb);
float l9_1=l9_0.y;
float l9_2=l9_0.z-(l9_1*0.5);
return vec3(l9_0.x,l9_1/((1.0-abs((2.0*l9_2)-1.0))+1e-07),l9_2);
}
vec3 HUEtoRGB(float hue)
{
return clamp(vec3(abs((6.0*hue)-3.0)-1.0,2.0-abs((6.0*hue)-2.0),2.0-abs((6.0*hue)-4.0)),vec3(0.0),vec3(1.0));
}
vec3 HSLToRGB(vec3 hsl)
{
return ((HUEtoRGB(hsl.x)-vec3(0.5))*((1.0-abs((2.0*hsl.z)-1.0))*hsl.y))+vec3(hsl.z);
}
vec3 transformColor(float yValue,vec3 original,vec3 target,float weight,float intMap)
{
#if (BLEND_MODE_INTENSE)
{
return mix(original,HSLToRGB(vec3(target.x,target.y,RGBToHSL(original).z)),vec3(weight));
}
#else
{
return mix(original,clamp(vec3(transformSingleColor(yValue,intMap,target.x),transformSingleColor(yValue,intMap,target.y),transformSingleColor(yValue,intMap,target.z)),vec3(0.0),vec3(1.0)),vec3(weight));
}
#endif
}
vec3 definedBlend(vec3 a,vec3 b)
{
#if (BLEND_MODE_LIGHTEN)
{
return max(a,b);
}
#else
{
#if (BLEND_MODE_DARKEN)
{
return min(a,b);
}
#else
{
#if (BLEND_MODE_DIVIDE)
{
return b/a;
}
#else
{
#if (BLEND_MODE_AVERAGE)
{
return (a+b)*0.5;
}
#else
{
#if (BLEND_MODE_SUBTRACT)
{
return max((a+b)-vec3(1.0),vec3(0.0));
}
#else
{
#if (BLEND_MODE_DIFFERENCE)
{
return abs(a-b);
}
#else
{
#if (BLEND_MODE_NEGATION)
{
return vec3(1.0)-abs((vec3(1.0)-a)-b);
}
#else
{
#if (BLEND_MODE_EXCLUSION)
{
return (a+b)-((a*2.0)*b);
}
#else
{
#if (BLEND_MODE_OVERLAY)
{
float l9_0;
if (a.x<0.5)
{
l9_0=(2.0*a.x)*b.x;
}
else
{
l9_0=1.0-((2.0*(1.0-a.x))*(1.0-b.x));
}
float l9_1;
if (a.y<0.5)
{
l9_1=(2.0*a.y)*b.y;
}
else
{
l9_1=1.0-((2.0*(1.0-a.y))*(1.0-b.y));
}
float l9_2;
if (a.z<0.5)
{
l9_2=(2.0*a.z)*b.z;
}
else
{
l9_2=1.0-((2.0*(1.0-a.z))*(1.0-b.z));
}
return vec3(l9_0,l9_1,l9_2);
}
#else
{
#if (BLEND_MODE_SOFT_LIGHT)
{
return (((vec3(1.0)-(b*2.0))*a)*a)+((a*2.0)*b);
}
#else
{
#if (BLEND_MODE_HARD_LIGHT)
{
float l9_3;
if (b.x<0.5)
{
l9_3=(2.0*b.x)*a.x;
}
else
{
l9_3=1.0-((2.0*(1.0-b.x))*(1.0-a.x));
}
float l9_4;
if (b.y<0.5)
{
l9_4=(2.0*b.y)*a.y;
}
else
{
l9_4=1.0-((2.0*(1.0-b.y))*(1.0-a.y));
}
float l9_5;
if (b.z<0.5)
{
l9_5=(2.0*b.z)*a.z;
}
else
{
l9_5=1.0-((2.0*(1.0-b.z))*(1.0-a.z));
}
return vec3(l9_3,l9_4,l9_5);
}
#else
{
#if (BLEND_MODE_COLOR_DODGE)
{
float l9_6;
if (b.x==1.0)
{
l9_6=b.x;
}
else
{
l9_6=min(a.x/(1.0-b.x),1.0);
}
float l9_7;
if (b.y==1.0)
{
l9_7=b.y;
}
else
{
l9_7=min(a.y/(1.0-b.y),1.0);
}
float l9_8;
if (b.z==1.0)
{
l9_8=b.z;
}
else
{
l9_8=min(a.z/(1.0-b.z),1.0);
}
return vec3(l9_6,l9_7,l9_8);
}
#else
{
#if (BLEND_MODE_COLOR_BURN)
{
float l9_9;
if (b.x==0.0)
{
l9_9=b.x;
}
else
{
l9_9=max(1.0-((1.0-a.x)/b.x),0.0);
}
float l9_10;
if (b.y==0.0)
{
l9_10=b.y;
}
else
{
l9_10=max(1.0-((1.0-a.y)/b.y),0.0);
}
float l9_11;
if (b.z==0.0)
{
l9_11=b.z;
}
else
{
l9_11=max(1.0-((1.0-a.z)/b.z),0.0);
}
return vec3(l9_9,l9_10,l9_11);
}
#else
{
#if (BLEND_MODE_LINEAR_LIGHT)
{
float l9_12;
if (b.x<0.5)
{
l9_12=max((a.x+(2.0*b.x))-1.0,0.0);
}
else
{
l9_12=min(a.x+(2.0*(b.x-0.5)),1.0);
}
float l9_13;
if (b.y<0.5)
{
l9_13=max((a.y+(2.0*b.y))-1.0,0.0);
}
else
{
l9_13=min(a.y+(2.0*(b.y-0.5)),1.0);
}
float l9_14;
if (b.z<0.5)
{
l9_14=max((a.z+(2.0*b.z))-1.0,0.0);
}
else
{
l9_14=min(a.z+(2.0*(b.z-0.5)),1.0);
}
return vec3(l9_12,l9_13,l9_14);
}
#else
{
#if (BLEND_MODE_VIVID_LIGHT)
{
float l9_15;
if (b.x<0.5)
{
float l9_16;
if ((2.0*b.x)==0.0)
{
l9_16=2.0*b.x;
}
else
{
l9_16=max(1.0-((1.0-a.x)/(2.0*b.x)),0.0);
}
l9_15=l9_16;
}
else
{
float l9_17;
if ((2.0*(b.x-0.5))==1.0)
{
l9_17=2.0*(b.x-0.5);
}
else
{
l9_17=min(a.x/(1.0-(2.0*(b.x-0.5))),1.0);
}
l9_15=l9_17;
}
float l9_18;
if (b.y<0.5)
{
float l9_19;
if ((2.0*b.y)==0.0)
{
l9_19=2.0*b.y;
}
else
{
l9_19=max(1.0-((1.0-a.y)/(2.0*b.y)),0.0);
}
l9_18=l9_19;
}
else
{
float l9_20;
if ((2.0*(b.y-0.5))==1.0)
{
l9_20=2.0*(b.y-0.5);
}
else
{
l9_20=min(a.y/(1.0-(2.0*(b.y-0.5))),1.0);
}
l9_18=l9_20;
}
float l9_21;
if (b.z<0.5)
{
float l9_22;
if ((2.0*b.z)==0.0)
{
l9_22=2.0*b.z;
}
else
{
l9_22=max(1.0-((1.0-a.z)/(2.0*b.z)),0.0);
}
l9_21=l9_22;
}
else
{
float l9_23;
if ((2.0*(b.z-0.5))==1.0)
{
l9_23=2.0*(b.z-0.5);
}
else
{
l9_23=min(a.z/(1.0-(2.0*(b.z-0.5))),1.0);
}
l9_21=l9_23;
}
return vec3(l9_15,l9_18,l9_21);
}
#else
{
#if (BLEND_MODE_PIN_LIGHT)
{
float l9_24;
if (b.x<0.5)
{
l9_24=min(a.x,2.0*b.x);
}
else
{
l9_24=max(a.x,2.0*(b.x-0.5));
}
float l9_25;
if (b.y<0.5)
{
l9_25=min(a.y,2.0*b.y);
}
else
{
l9_25=max(a.y,2.0*(b.y-0.5));
}
float l9_26;
if (b.z<0.5)
{
l9_26=min(a.z,2.0*b.z);
}
else
{
l9_26=max(a.z,2.0*(b.z-0.5));
}
return vec3(l9_24,l9_25,l9_26);
}
#else
{
#if (BLEND_MODE_HARD_MIX)
{
float l9_27;
if (b.x<0.5)
{
float l9_28;
if ((2.0*b.x)==0.0)
{
l9_28=2.0*b.x;
}
else
{
l9_28=max(1.0-((1.0-a.x)/(2.0*b.x)),0.0);
}
l9_27=l9_28;
}
else
{
float l9_29;
if ((2.0*(b.x-0.5))==1.0)
{
l9_29=2.0*(b.x-0.5);
}
else
{
l9_29=min(a.x/(1.0-(2.0*(b.x-0.5))),1.0);
}
l9_27=l9_29;
}
bool l9_30=l9_27<0.5;
float l9_31;
if (b.y<0.5)
{
float l9_32;
if ((2.0*b.y)==0.0)
{
l9_32=2.0*b.y;
}
else
{
l9_32=max(1.0-((1.0-a.y)/(2.0*b.y)),0.0);
}
l9_31=l9_32;
}
else
{
float l9_33;
if ((2.0*(b.y-0.5))==1.0)
{
l9_33=2.0*(b.y-0.5);
}
else
{
l9_33=min(a.y/(1.0-(2.0*(b.y-0.5))),1.0);
}
l9_31=l9_33;
}
bool l9_34=l9_31<0.5;
float l9_35;
if (b.z<0.5)
{
float l9_36;
if ((2.0*b.z)==0.0)
{
l9_36=2.0*b.z;
}
else
{
l9_36=max(1.0-((1.0-a.z)/(2.0*b.z)),0.0);
}
l9_35=l9_36;
}
else
{
float l9_37;
if ((2.0*(b.z-0.5))==1.0)
{
l9_37=2.0*(b.z-0.5);
}
else
{
l9_37=min(a.z/(1.0-(2.0*(b.z-0.5))),1.0);
}
l9_35=l9_37;
}
return vec3(l9_30 ? 0.0 : 1.0,l9_34 ? 0.0 : 1.0,(l9_35<0.5) ? 0.0 : 1.0);
}
#else
{
#if (BLEND_MODE_HARD_REFLECT)
{
float l9_38;
if (b.x==1.0)
{
l9_38=b.x;
}
else
{
l9_38=min((a.x*a.x)/(1.0-b.x),1.0);
}
float l9_39;
if (b.y==1.0)
{
l9_39=b.y;
}
else
{
l9_39=min((a.y*a.y)/(1.0-b.y),1.0);
}
float l9_40;
if (b.z==1.0)
{
l9_40=b.z;
}
else
{
l9_40=min((a.z*a.z)/(1.0-b.z),1.0);
}
return vec3(l9_38,l9_39,l9_40);
}
#else
{
#if (BLEND_MODE_HARD_GLOW)
{
float l9_41;
if (a.x==1.0)
{
l9_41=a.x;
}
else
{
l9_41=min((b.x*b.x)/(1.0-a.x),1.0);
}
float l9_42;
if (a.y==1.0)
{
l9_42=a.y;
}
else
{
l9_42=min((b.y*b.y)/(1.0-a.y),1.0);
}
float l9_43;
if (a.z==1.0)
{
l9_43=a.z;
}
else
{
l9_43=min((b.z*b.z)/(1.0-a.z),1.0);
}
return vec3(l9_41,l9_42,l9_43);
}
#else
{
#if (BLEND_MODE_HARD_PHOENIX)
{
return (min(a,b)-max(a,b))+vec3(1.0);
}
#else
{
#if (BLEND_MODE_HUE)
{
return HSLToRGB(vec3(RGBToHSL(b).x,RGBToHSL(a).yz));
}
#else
{
#if (BLEND_MODE_SATURATION)
{
vec3 l9_44=RGBToHSL(a);
return HSLToRGB(vec3(l9_44.x,RGBToHSL(b).y,l9_44.z));
}
#else
{
#if (BLEND_MODE_COLOR)
{
return HSLToRGB(vec3(RGBToHSL(b).xy,RGBToHSL(a).z));
}
#else
{
#if (BLEND_MODE_LUMINOSITY)
{
return HSLToRGB(vec3(RGBToHSL(a).xy,RGBToHSL(b).z));
}
#else
{
vec3 l9_45=a;
vec3 l9_46=b;
float l9_47=((0.29899999*l9_45.x)+(0.58700001*l9_45.y))+(0.114*l9_45.z);
float l9_48=pow(l9_47,1.0/correctedIntensity);
vec4 l9_49;
#if (intensityTextureLayout==2)
{
l9_49=sc_SampleTextureBiasOrLevel(intensityTextureDims.xy,intensityTextureLayout,intensityTextureGetStereoViewIndex(),vec2(l9_48,0.5),(int(SC_USE_UV_TRANSFORM_intensityTexture)!=0),intensityTextureTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_intensityTexture,SC_SOFTWARE_WRAP_MODE_V_intensityTexture),(int(SC_USE_UV_MIN_MAX_intensityTexture)!=0),intensityTextureUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_intensityTexture)!=0),intensityTextureBorderColor,0.0,intensityTextureArrSC);
}
#else
{
l9_49=sc_SampleTextureBiasOrLevel(intensityTextureDims.xy,intensityTextureLayout,intensityTextureGetStereoViewIndex(),vec2(l9_48,0.5),(int(SC_USE_UV_TRANSFORM_intensityTexture)!=0),intensityTextureTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_intensityTexture,SC_SOFTWARE_WRAP_MODE_V_intensityTexture),(int(SC_USE_UV_MIN_MAX_intensityTexture)!=0),intensityTextureUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_intensityTexture)!=0),intensityTextureBorderColor,0.0,intensityTexture);
}
#endif
float l9_50=((((l9_49.x*256.0)+l9_49.y)+(l9_49.z/256.0))/257.00391)*16.0;
float l9_51;
#if (BLEND_MODE_FORGRAY)
{
l9_51=max(l9_50,1.0);
}
#else
{
l9_51=l9_50;
}
#endif
float l9_52;
#if (BLEND_MODE_NOTBRIGHT)
{
l9_52=min(l9_51,1.0);
}
#else
{
l9_52=l9_51;
}
#endif
return transformColor(l9_47,l9_45,l9_46,1.0,l9_52);
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
vec4 outputMotionVectorsIfNeeded(vec3 surfacePosWorldSpace,vec4 finalColor)
{
#if (sc_MotionVectorsPass)
{
vec4 l9_0=vec4(surfacePosWorldSpace,1.0);
vec4 l9_1=sc_ViewProjectionMatrixArray[sc_GetStereoViewIndex()]*l9_0;
vec4 l9_2=((sc_PrevFrameViewProjectionMatrixArray[sc_GetStereoViewIndex()]*sc_PrevFrameModelMatrix)*sc_ModelMatrixInverse)*l9_0;
vec2 l9_3=((l9_1.xy/vec2(l9_1.w)).xy-(l9_2.xy/vec2(l9_2.w)).xy)*0.5;
float l9_4=floor(((l9_3.x*5.0)+0.5)*65535.0);
float l9_5=floor(l9_4*0.00390625);
float l9_6=floor(((l9_3.y*5.0)+0.5)*65535.0);
float l9_7=floor(l9_6*0.00390625);
return vec4(l9_5/255.0,(l9_4-(l9_5*256.0))/255.0,l9_7/255.0,(l9_6-(l9_7*256.0))/255.0);
}
#else
{
return finalColor;
}
#endif
}
void sc_writeFragData0(vec4 col)
{
    sc_FragData0=col;
}
float getFrontLayerZTestEpsilon()
{
#if (sc_SkinBonesCount>0)
{
return 5e-07;
}
#else
{
return 5.0000001e-08;
}
#endif
}
void unpackValues(float channel,int passIndex,inout int values[8])
{
#if (sc_OITCompositingPass)
{
channel=floor((channel*255.0)+0.5);
int l9_0=((passIndex+1)*4)-1;
for (int snapLoopIndex=0; snapLoopIndex==0; snapLoopIndex+=0)
{
if (l9_0>=(passIndex*4))
{
values[l9_0]=(values[l9_0]*4)+int(floor(mod(channel,4.0)));
channel=floor(channel/4.0);
l9_0--;
continue;
}
else
{
break;
}
}
}
#endif
}
float getDepthOrderingEpsilon()
{
#if (sc_SkinBonesCount>0)
{
return 0.001;
}
#else
{
return 0.0;
}
#endif
}
int encodeDepth(float depth,vec2 depthBounds)
{
float l9_0=(1.0-depthBounds.x)*1000.0;
return int(clamp((depth-l9_0)/((depthBounds.y*1000.0)-l9_0),0.0,1.0)*65535.0);
}
float viewSpaceDepth()
{
#if (UseViewSpaceDepthVariant&&((sc_OITDepthGatherPass||sc_OITCompositingPass)||sc_OITDepthBoundsPass))
{
return varViewSpaceDepth;
}
#else
{
return sc_ProjectionMatrixArray[sc_GetStereoViewIndex()][3].z/(sc_ProjectionMatrixArray[sc_GetStereoViewIndex()][2].z+((gl_FragCoord.z*2.0)-1.0));
}
#endif
}
float packValue(inout int value)
{
#if (sc_OITDepthGatherPass)
{
int l9_0=value;
value/=4;
return floor(floor(mod(float(l9_0),4.0))*64.0)/255.0;
}
#else
{
return 0.0;
}
#endif
}
void sc_writeFragData1(vec4 col)
{
#if sc_FragDataCount>=2
    sc_FragData1=col;
#endif
}
void sc_writeFragData2(vec4 col)
{
#if sc_FragDataCount>=3
    sc_FragData2=col;
#endif
}
void main()
{
#if (sc_DepthOnly)
{
return;
}
#endif
#if ((sc_StereoRenderingMode==1)&&(sc_StereoRendering_IsClipDistanceEnabled==0))
{
if (varClipDistance<0.0)
{
discard;
}
}
#endif
vec2 l9_0=gl_FragCoord.xy*sc_CurrentRenderTargetDims.zw;
vec2 l9_1=sc_ScreenCoordsGlobalToView(l9_0);
vec4 l9_2;
#if (camTexLayout==2)
{
l9_2=sc_SampleTextureBiasOrLevel(camTexDims.xy,camTexLayout,camTexGetStereoViewIndex(),l9_1,(int(SC_USE_UV_TRANSFORM_camTex)!=0),camTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_camTex,SC_SOFTWARE_WRAP_MODE_V_camTex),(int(SC_USE_UV_MIN_MAX_camTex)!=0),camTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_camTex)!=0),camTexBorderColor,0.0,camTexArrSC);
}
#else
{
l9_2=sc_SampleTextureBiasOrLevel(camTexDims.xy,camTexLayout,camTexGetStereoViewIndex(),l9_1,(int(SC_USE_UV_TRANSFORM_camTex)!=0),camTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_camTex,SC_SOFTWARE_WRAP_MODE_V_camTex),(int(SC_USE_UV_MIN_MAX_camTex)!=0),camTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_camTex)!=0),camTexBorderColor,0.0,camTex);
}
#endif
vec2 l9_3=((l9_1+((cropCenter-(cropSize*0.5))*(-1.0)))*(vec2(1.0)/cropSize))-vec2(0.0);
vec2 l9_4=(((vec2(flowHalfPx)+((l9_3*((1.0-flowHalfPx)-flowHalfPx))/vec2(1.0)))-vec2(0.5))*vec2(1.0,-1.0))+vec2(0.5);
float l9_5=l9_4.x;
float l9_6=l9_5*0.2;
float l9_7=l9_4.y;
float l9_8=l9_5*0.33333334;
vec4 l9_9=N52_sampleBiLinearRelative(vec2(l9_6,l9_7));
vec4 l9_10=N52_sampleBiLinearRelative(vec2(l9_6+0.2,l9_7));
vec4 l9_11=N52_sampleBiLinearRelative(vec2(l9_6+0.40000001,l9_7));
vec4 l9_12=N52_sampleBiLinearRelative(vec2(l9_6+0.60000002,l9_7));
vec4 l9_13=N52_sampleBiLinearRelative(vec2(l9_6+0.80000001,l9_7));
vec4 l9_14=N52_sampleBiLinearSelection(vec2(l9_8,l9_7));
vec4 l9_15=N52_sampleBiLinearSelection(vec2(l9_8+0.33333334,l9_7));
vec4 l9_16=N52_sampleBiLinearSelection(vec2(l9_8+0.66666669,l9_7));
float l9_17=l9_14.x;
float l9_18=l9_14.y;
float l9_19=l9_15.x;
float l9_20=l9_15.y;
float l9_21=l9_16.x;
float l9_22=max(max(max(max(l9_17,l9_18),l9_19),l9_20),l9_21);
float l9_23=exp(l9_17-l9_22);
float l9_24=exp(l9_18-l9_22);
float l9_25=exp(l9_19-l9_22);
float l9_26=exp(l9_20-l9_22);
float l9_27=exp(l9_21-l9_22);
float l9_28=(((l9_23+l9_24)+l9_25)+l9_26)+l9_27;
vec2 l9_29=((l9_4*2.0)-vec2(1.0))+(((((l9_9.xy*(l9_23/l9_28))+(l9_10.xy*(l9_24/l9_28)))+(l9_11.xy*(l9_25/l9_28)))+(l9_12.xy*(l9_26/l9_28)))+(l9_13.xy*(l9_27/l9_28)));
vec2 l9_30=(((l9_29*vec2(sx,sy))+vec2(dx,dy))+vec2(1.0))/vec2(2.0);
vec2 l9_31=vec2(l9_30.x,1.0-l9_30.y);
vec4 l9_32;
#if (sourceCropTexLayout==2)
{
l9_32=sc_SampleTextureBiasOrLevel(sourceCropTexDims.xy,sourceCropTexLayout,sourceCropTexGetStereoViewIndex(),l9_31,(int(SC_USE_UV_TRANSFORM_sourceCropTex)!=0),sourceCropTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_sourceCropTex,SC_SOFTWARE_WRAP_MODE_V_sourceCropTex),(int(SC_USE_UV_MIN_MAX_sourceCropTex)!=0),sourceCropTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_sourceCropTex)!=0),sourceCropTexBorderColor,0.0,sourceCropTexArrSC);
}
#else
{
l9_32=sc_SampleTextureBiasOrLevel(sourceCropTexDims.xy,sourceCropTexLayout,sourceCropTexGetStereoViewIndex(),l9_31,(int(SC_USE_UV_TRANSFORM_sourceCropTex)!=0),sourceCropTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_sourceCropTex,SC_SOFTWARE_WRAP_MODE_V_sourceCropTex),(int(SC_USE_UV_MIN_MAX_sourceCropTex)!=0),sourceCropTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_sourceCropTex)!=0),sourceCropTexBorderColor,0.0,sourceCropTex);
}
#endif
vec2 l9_33=vec2((0.5*l9_29.x)+0.5,((-0.5)*l9_29.y)+0.5);
vec4 l9_34;
#if (sourceGarmentMaskLayout==2)
{
l9_34=sc_SampleTextureBiasOrLevel(sourceGarmentMaskDims.xy,sourceGarmentMaskLayout,sourceGarmentMaskGetStereoViewIndex(),l9_33,(int(SC_USE_UV_TRANSFORM_sourceGarmentMask)!=0),sourceGarmentMaskTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_sourceGarmentMask,SC_SOFTWARE_WRAP_MODE_V_sourceGarmentMask),(int(SC_USE_UV_MIN_MAX_sourceGarmentMask)!=0),sourceGarmentMaskUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_sourceGarmentMask)!=0),sourceGarmentMaskBorderColor,0.0,sourceGarmentMaskArrSC);
}
#else
{
l9_34=sc_SampleTextureBiasOrLevel(sourceGarmentMaskDims.xy,sourceGarmentMaskLayout,sourceGarmentMaskGetStereoViewIndex(),l9_33,(int(SC_USE_UV_TRANSFORM_sourceGarmentMask)!=0),sourceGarmentMaskTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_sourceGarmentMask,SC_SOFTWARE_WRAP_MODE_V_sourceGarmentMask),(int(SC_USE_UV_MIN_MAX_sourceGarmentMask)!=0),sourceGarmentMaskUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_sourceGarmentMask)!=0),sourceGarmentMaskBorderColor,0.0,sourceGarmentMask);
}
#endif
vec2 l9_35=vec2(shaderMaskHalfPx)+((l9_3*((1.0-shaderMaskHalfPx)-shaderMaskHalfPx))/vec2(1.0));
vec4 l9_36;
#if (shaderMasksTexLayout==2)
{
l9_36=sc_SampleTextureBiasOrLevel(shaderMasksTexDims.xy,shaderMasksTexLayout,shaderMasksTexGetStereoViewIndex(),l9_35,(int(SC_USE_UV_TRANSFORM_shaderMasksTex)!=0),shaderMasksTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_shaderMasksTex,SC_SOFTWARE_WRAP_MODE_V_shaderMasksTex),(int(SC_USE_UV_MIN_MAX_shaderMasksTex)!=0),shaderMasksTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_shaderMasksTex)!=0),shaderMasksTexBorderColor,0.0,shaderMasksTexArrSC);
}
#else
{
l9_36=sc_SampleTextureBiasOrLevel(shaderMasksTexDims.xy,shaderMasksTexLayout,shaderMasksTexGetStereoViewIndex(),l9_35,(int(SC_USE_UV_TRANSFORM_shaderMasksTex)!=0),shaderMasksTexTransform,ivec2(SC_SOFTWARE_WRAP_MODE_U_shaderMasksTex,SC_SOFTWARE_WRAP_MODE_V_shaderMasksTex),(int(SC_USE_UV_MIN_MAX_shaderMasksTex)!=0),shaderMasksTexUvMinMax,(int(SC_USE_CLAMP_TO_BORDER_shaderMasksTex)!=0),shaderMasksTexBorderColor,0.0,shaderMasksTex);
}
#endif
float l9_37=(step(0.80000001,l9_34.x)*l9_36.w)*gridSampAlpha;
vec2 l9_38=vec2(1.0)/genTexSize.xy;
vec2 l9_39=(((((vec2(genHalfPx)+((l9_3*((1.0-genHalfPx)-genHalfPx))/vec2(1.0)))-vec2(0.5))*vec2(1.0,-1.0))+vec2(0.5))*genTexSize.xy)+vec2(0.5);
vec2 l9_40=fract(l9_39);
vec2 l9_41=(floor(l9_39)/genTexSize.xy)-(l9_38/vec2(2.0));
vec4 l9_42=N52_generatedTex_sample(l9_41);
vec4 l9_43=N52_generatedTex_sample(l9_41+vec2(l9_38.x,0.0));
vec4 l9_44=N52_generatedTex_sample(l9_41+vec2(0.0,l9_38.y));
vec4 l9_45=N52_generatedTex_sample(l9_41+l9_38);
vec4 l9_46=vec4(l9_40.x);
vec2 l9_47=vec2(1.0)/drivingHairMaskSize.xy;
vec2 l9_48=(vec2((l9_1.x+segShiftX)*segRatioX,(l9_1.y+segShiftY)*segRatioY)*drivingHairMaskSize.xy)+vec2(0.5);
vec2 l9_49=fract(l9_48);
vec2 l9_50=(floor(l9_48)/drivingHairMaskSize.xy)-(l9_47/vec2(2.0));
vec4 l9_51=N52_drivinghairTex_sample(l9_50);
vec4 l9_52=N52_drivinghairTex_sample(l9_50+vec2(l9_47.x,0.0));
vec4 l9_53=N52_drivinghairTex_sample(l9_50+vec2(0.0,l9_47.y));
vec4 l9_54=N52_drivinghairTex_sample(l9_50+l9_47);
vec4 l9_55=vec4(l9_49.x);
float l9_56=step(0.30000001,l9_36.y)*l9_36.z;
float l9_57=(((1.0-mix(mix(l9_51,l9_52,l9_55),mix(l9_53,l9_54,l9_55),vec4(l9_49.y)).x)*l9_56)*step(0.69999999,l9_56))*genAlpha;
vec4 l9_58=vec4(1.0)/(vec4(1.0)+exp(-vec4(mix(mix(l9_42,l9_43,l9_46),mix(l9_44,l9_45,l9_46),vec4(l9_40.y)).xyz,0.0)));
vec4 l9_59=vec4((vec4(l9_32.xyz,l9_37).xyz*l9_37)+(l9_58.xyz*(1.0-l9_37)),1.0);
bvec4 l9_60=bvec4(float(useShaderGridSample)==1.0);
float l9_61=(1.0*l9_57)+0.0;
vec4 l9_62=vec4((vec4(vec4(l9_60.x ? l9_59.x : l9_58.x,l9_60.y ? l9_59.y : l9_58.y,l9_60.z ? l9_59.z : l9_58.z,l9_60.w ? l9_59.w : l9_58.w).xyz,l9_57).xyz*l9_61)+(l9_2.xyz*(1.0-l9_61)),1.0);
#if (sc_BlendMode_AlphaTest)
{
if (1.0<alphaTestThreshold)
{
discard;
}
}
#endif
#if (ENABLE_STIPPLE_PATTERN_TEST)
{
if (1.0<((mod(dot(floor(mod(gl_FragCoord.xy,vec2(4.0))),vec2(4.0,1.0))*9.0,16.0)+1.0)/17.0))
{
discard;
}
}
#endif
vec4 l9_63;
#if (sc_ProjectiveShadowsCaster)
{
float l9_64;
#if (((sc_BlendMode_Normal||sc_BlendMode_AlphaToCoverage)||sc_BlendMode_PremultipliedAlphaHardware)||sc_BlendMode_PremultipliedAlphaAuto)
{
l9_64=1.0;
}
#else
{
float l9_65;
#if (sc_BlendMode_PremultipliedAlpha)
{
l9_65=clamp(1.0*2.0,0.0,1.0);
}
#else
{
float l9_66;
#if (sc_BlendMode_AddWithAlphaFactor)
{
l9_66=clamp(dot(l9_62.xyz,vec3(1.0)),0.0,1.0);
}
#else
{
float l9_67;
#if (sc_BlendMode_AlphaTest)
{
l9_67=1.0;
}
#else
{
float l9_68;
#if (sc_BlendMode_Multiply)
{
l9_68=(1.0-dot(l9_62.xyz,vec3(0.33333001)))*1.0;
}
#else
{
float l9_69;
#if (sc_BlendMode_MultiplyOriginal)
{
l9_69=(1.0-clamp(dot(l9_62.xyz,vec3(1.0)),0.0,1.0))*1.0;
}
#else
{
float l9_70;
#if (sc_BlendMode_ColoredGlass)
{
l9_70=clamp(dot(l9_62.xyz,vec3(1.0)),0.0,1.0)*1.0;
}
#else
{
float l9_71;
#if (sc_BlendMode_Add)
{
l9_71=clamp(dot(l9_62.xyz,vec3(1.0)),0.0,1.0);
}
#else
{
float l9_72;
#if (sc_BlendMode_AddWithAlphaFactor)
{
l9_72=clamp(dot(l9_62.xyz,vec3(1.0)),0.0,1.0)*1.0;
}
#else
{
float l9_73;
#if (sc_BlendMode_Screen)
{
l9_73=dot(l9_62.xyz,vec3(0.33333001))*1.0;
}
#else
{
float l9_74;
#if (sc_BlendMode_Min)
{
l9_74=1.0-clamp(dot(l9_62.xyz,vec3(1.0)),0.0,1.0);
}
#else
{
float l9_75;
#if (sc_BlendMode_Max)
{
l9_75=clamp(dot(l9_62.xyz,vec3(1.0)),0.0,1.0);
}
#else
{
l9_75=1.0;
}
#endif
l9_74=l9_75;
}
#endif
l9_73=l9_74;
}
#endif
l9_72=l9_73;
}
#endif
l9_71=l9_72;
}
#endif
l9_70=l9_71;
}
#endif
l9_69=l9_70;
}
#endif
l9_68=l9_69;
}
#endif
l9_67=l9_68;
}
#endif
l9_66=l9_67;
}
#endif
l9_65=l9_66;
}
#endif
l9_64=l9_65;
}
#endif
l9_63=vec4(mix(sc_ShadowColor.xyz,sc_ShadowColor.xyz*l9_62.xyz,vec3(sc_ShadowColor.w)),sc_ShadowDensity*l9_64);
}
#else
{
vec4 l9_76;
#if (sc_RenderAlphaToColor)
{
l9_76=vec4(1.0);
}
#else
{
vec4 l9_77;
#if (sc_BlendMode_Custom)
{
vec4 l9_78;
#if (sc_FramebufferFetch)
{
vec4 l9_79=sc_readFragData0_Platform();
vec4 l9_80;
#if (sc_UseFramebufferFetchMarker)
{
vec4 l9_81=l9_79;
l9_81.x=l9_79.x+_sc_framebufferFetchMarker;
l9_80=l9_81;
}
#else
{
l9_80=l9_79;
}
#endif
l9_78=l9_80;
}
#else
{
vec2 l9_82=sc_ScreenCoordsGlobalToView(l9_0);
int l9_83;
#if (sc_ScreenTextureHasSwappedViews)
{
l9_83=1-sc_GetStereoViewIndex();
}
#else
{
l9_83=sc_GetStereoViewIndex();
}
#endif
vec4 l9_84;
#if (sc_ScreenTextureLayout==2)
{
l9_84=sc_SampleView(sc_ScreenTextureDims.xy,l9_82,sc_ScreenTextureLayout,l9_83,0.0,sc_ScreenTextureArrSC);
}
#else
{
l9_84=sc_SampleView(sc_ScreenTextureDims.xy,l9_82,sc_ScreenTextureLayout,l9_83,0.0,sc_ScreenTexture);
}
#endif
l9_78=l9_84;
}
#endif
vec4 l9_85;
#if (((sc_IsEditor&&sc_GetFramebufferColorInvalidUsageMarker)&&(!sc_BlendMode_Software))&&(!sc_BlendMode_ColoredGlass))
{
vec4 l9_86=l9_78;
l9_86.x=l9_78.x+_sc_GetFramebufferColorInvalidUsageMarker;
l9_85=l9_86;
}
#else
{
l9_85=l9_78;
}
#endif
vec3 l9_87=definedBlend(l9_85.xyz,l9_62.xyz);
vec4 l9_88=vec4(l9_87.x,l9_87.y,l9_87.z,vec4(0.0).w);
l9_88.w=1.0;
l9_77=l9_88;
}
#else
{
vec4 l9_89;
#if (sc_BlendMode_MultiplyOriginal)
{
l9_89=l9_62;
}
#else
{
vec4 l9_90;
#if (sc_BlendMode_Screen||sc_BlendMode_PremultipliedAlphaAuto)
{
l9_90=vec4(l9_62.xyz*1.0,1.0);
}
#else
{
l9_90=l9_62;
}
#endif
l9_89=l9_90;
}
#endif
l9_77=l9_89;
}
#endif
l9_76=l9_77;
}
#endif
l9_63=l9_76;
}
#endif
vec4 l9_91;
if (PreviewEnabled==1)
{
vec4 l9_92;
if (((PreviewVertexSaved*1.0)!=0.0) ? true : false)
{
l9_92=PreviewVertexColor;
}
else
{
l9_92=vec4(0.0);
}
l9_91=l9_92;
}
else
{
l9_91=l9_63;
}
vec4 l9_93;
#if (sc_ShaderComplexityAnalyzer)
{
l9_93=vec4(shaderComplexityValue/255.0,0.0,0.0,1.0);
}
#else
{
l9_93=vec4(0.0);
}
#endif
vec4 l9_94;
if (l9_93.w>0.0)
{
l9_94=l9_93;
}
else
{
l9_94=l9_91;
}
vec4 l9_95=outputMotionVectorsIfNeeded(varPos,max(l9_94,vec4(0.0)));
vec4 l9_96=clamp(l9_95,vec4(0.0),vec4(1.0));
#if (sc_OITDepthBoundsPass)
{
#if (sc_OITDepthBoundsPass)
{
float l9_97=clamp(viewSpaceDepth()/1000.0,0.0,1.0);
sc_writeFragData0(vec4(max(0.0,1.0-(l9_97-0.0039215689)),min(1.0,l9_97+0.0039215689),0.0,0.0));
}
#endif
}
#else
{
#if (sc_OITDepthPrepass)
{
sc_writeFragData0(vec4(1.0));
}
#else
{
#if (sc_OITDepthGatherPass)
{
#if (sc_OITDepthGatherPass)
{
vec2 l9_98=sc_ScreenCoordsGlobalToView(l9_0);
#if (sc_OITMaxLayers4Plus1)
{
if ((gl_FragCoord.z-texture(sc_OITFrontDepthTexture,l9_98).x)<=getFrontLayerZTestEpsilon())
{
discard;
}
}
#endif
int l9_99=encodeDepth(viewSpaceDepth(),texture(sc_OITFilteredDepthBoundsTexture,l9_98).xy);
float l9_100=packValue(l9_99);
int l9_107=int(l9_96.w*255.0);
float l9_108=packValue(l9_107);
sc_writeFragData0(vec4(packValue(l9_99),packValue(l9_99),packValue(l9_99),packValue(l9_99)));
sc_writeFragData1(vec4(l9_100,packValue(l9_99),packValue(l9_99),packValue(l9_99)));
sc_writeFragData2(vec4(l9_108,packValue(l9_107),packValue(l9_107),packValue(l9_107)));
#if (sc_OITMaxLayersVisualizeLayerCount)
{
sc_writeFragData2(vec4(0.0039215689,0.0,0.0,0.0));
}
#endif
}
#endif
}
#else
{
#if (sc_OITCompositingPass)
{
#if (sc_OITCompositingPass)
{
vec2 l9_111=sc_ScreenCoordsGlobalToView(l9_0);
#if (sc_OITMaxLayers4Plus1)
{
if ((gl_FragCoord.z-texture(sc_OITFrontDepthTexture,l9_111).x)<=getFrontLayerZTestEpsilon())
{
discard;
}
}
#endif
int l9_112[8];
int l9_113[8];
int l9_114=0;
for (int snapLoopIndex=0; snapLoopIndex==0; snapLoopIndex+=0)
{
if (l9_114<8)
{
l9_112[l9_114]=0;
l9_113[l9_114]=0;
l9_114++;
continue;
}
else
{
break;
}
}
int l9_115;
#if (sc_OITMaxLayers8)
{
l9_115=2;
}
#else
{
l9_115=1;
}
#endif
int l9_116=0;
for (int snapLoopIndex=0; snapLoopIndex==0; snapLoopIndex+=0)
{
if (l9_116<l9_115)
{
vec4 l9_117;
vec4 l9_118;
vec4 l9_119;
if (l9_116==0)
{
l9_119=texture(sc_OITAlpha0,l9_111);
l9_118=texture(sc_OITDepthLow0,l9_111);
l9_117=texture(sc_OITDepthHigh0,l9_111);
}
else
{
l9_119=vec4(0.0);
l9_118=vec4(0.0);
l9_117=vec4(0.0);
}
vec4 l9_120;
vec4 l9_121;
vec4 l9_122;
if (l9_116==1)
{
l9_122=texture(sc_OITAlpha1,l9_111);
l9_121=texture(sc_OITDepthLow1,l9_111);
l9_120=texture(sc_OITDepthHigh1,l9_111);
}
else
{
l9_122=l9_119;
l9_121=l9_118;
l9_120=l9_117;
}
if (any(notEqual(l9_120,vec4(0.0)))||any(notEqual(l9_121,vec4(0.0))))
{
int l9_123[8]=l9_112;
unpackValues(l9_120.w,l9_116,l9_123);
unpackValues(l9_120.z,l9_116,l9_123);
unpackValues(l9_120.y,l9_116,l9_123);
unpackValues(l9_120.x,l9_116,l9_123);
unpackValues(l9_121.w,l9_116,l9_123);
unpackValues(l9_121.z,l9_116,l9_123);
unpackValues(l9_121.y,l9_116,l9_123);
unpackValues(l9_121.x,l9_116,l9_123);
int l9_132[8]=l9_113;
unpackValues(l9_122.w,l9_116,l9_132);
unpackValues(l9_122.z,l9_116,l9_132);
unpackValues(l9_122.y,l9_116,l9_132);
unpackValues(l9_122.x,l9_116,l9_132);
}
l9_116++;
continue;
}
else
{
break;
}
}
vec4 l9_137=texture(sc_OITFilteredDepthBoundsTexture,l9_111);
vec2 l9_138=l9_137.xy;
int l9_139;
#if (sc_SkinBonesCount>0)
{
l9_139=encodeDepth(((1.0-l9_137.x)*1000.0)+getDepthOrderingEpsilon(),l9_138);
}
#else
{
l9_139=0;
}
#endif
int l9_140=encodeDepth(viewSpaceDepth(),l9_138);
vec4 l9_141;
l9_141=l9_96*l9_96.w;
vec4 l9_142;
int l9_143=0;
for (int snapLoopIndex=0; snapLoopIndex==0; snapLoopIndex+=0)
{
if (l9_143<8)
{
int l9_144=l9_112[l9_143];
int l9_145=l9_140-l9_139;
bool l9_146=l9_144<l9_145;
bool l9_147;
if (l9_146)
{
l9_147=l9_112[l9_143]>0;
}
else
{
l9_147=l9_146;
}
if (l9_147)
{
vec3 l9_148=l9_141.xyz*(1.0-(float(l9_113[l9_143])/255.0));
l9_142=vec4(l9_148.x,l9_148.y,l9_148.z,l9_141.w);
}
else
{
l9_142=l9_141;
}
l9_141=l9_142;
l9_143++;
continue;
}
else
{
break;
}
}
sc_writeFragData0(l9_141);
#if (sc_OITMaxLayersVisualizeLayerCount)
{
discard;
}
#endif
}
#endif
}
#else
{
#if (sc_OITFrontLayerPass)
{
#if (sc_OITFrontLayerPass)
{
if (abs(gl_FragCoord.z-texture(sc_OITFrontDepthTexture,sc_ScreenCoordsGlobalToView(l9_0)).x)>getFrontLayerZTestEpsilon())
{
discard;
}
sc_writeFragData0(l9_96);
}
#endif
}
#else
{
sc_writeFragData0(l9_95);
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif
}
#endif // #elif defined FRAGMENT_SHADER // #if defined VERTEX_SHADER
