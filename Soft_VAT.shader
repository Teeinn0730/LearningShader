Shader "Unlit/Soft_VAT"
{
    Properties
    {
        // Map Data
        [NoScaleOffset] _PositionMap ("Position Map", 2D) = "black" {}
        [NoScaleOffset] _NormalMap ("NormalMap Map", 2D) = "black" {}
        [NoScaleOffset] _RotationMap ("RotationMap Map", 2D) = "black" {}

        // Parameters
        _CurrentFrame ("Current Frame", Float) = 0
        _TotalFrames ("Total Frames", Float) = 0
        [Toggle] _FrameInterpolation ("Frame Interpolation", Float) = 0
        [Toggle] _LoadColorTexture ("Load Color Texture", Float) = 0
        [Toggle] _UseCompressedNormals ("Use Compressed Normals", Float) = 0
        _MaxBounds ("Max Bounds", Vector) = (1,1,1,0)
        _MinBounds ("Max Bounds", Vector) = (0,0,0,0)
    }
    SubShader
    {
        HLSLINCLUDE
        Texture2D _PositionMap, _NormalMap, _RotationMap;
        SamplerState sampler_point_clamp;

        half4 _MaxBounds, _MinBounds;
        half _CurrentFrame, _TotalFrames;
        uint _FrameInterpolation, _LoadColorTexture, _UseCompressedNormals;
        ENDHLSL

        Tags
        {
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
            "PreviewType" = "Plane"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Blend One Zero
            ZTest LEqual
            ZWrite On
            Cull Back
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float3 normal : NORMAL;
            };

            struct VertexOutput
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
            };

            float2 GetHoudini_SoftVAT_UV(in float currentFrame, in float totalFrame, in float2 activePixelsRatio, in float2 uv)
            {
                float2 CurrentFrameUV;
                float CurrentFrame = floor(currentFrame);
                CurrentFrame %= totalFrame;
                CurrentFrame *= 1 / totalFrame;
                CurrentFrame *= activePixelsRatio.y;
                CurrentFrameUV.x = uv.x * activePixelsRatio.x;
                CurrentFrameUV.y = 1 - ((1 - uv.y) * activePixelsRatio.y + CurrentFrame);
                return CurrentFrameUV;
            }

            float3 GetPackedNormal(in float posTexAlpha)
            {
                float2 SampleCurrentNormal = 0;
                SampleCurrentNormal.x = floor(posTexAlpha * 1024 / 32) / 31.5f;
                SampleCurrentNormal.y = (posTexAlpha * 1024 - floor(posTexAlpha * 1024 / 32) * 32) / 31.5f;
                SampleCurrentNormal = SampleCurrentNormal * 4 - 2;
                float DotNormal = dot(SampleCurrentNormal, SampleCurrentNormal);
                float3 CurrentNormal = 0;
                float2 CurrentNormalXZ = sqrt(1 - DotNormal / 4) * SampleCurrentNormal.xy;
                CurrentNormal.x = -CurrentNormalXZ.x;
                CurrentNormal.y = 1 - DotNormal / 2;
                CurrentNormal.z = CurrentNormalXZ.y;
                CurrentNormal = clamp(-1, 1, CurrentNormal);
                CurrentNormal = normalize(CurrentNormal);
                return CurrentNormal;
            }

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;

                float3 MaxBounds = _MaxBounds.xyz * 10;
                float3 MinBounds = _MinBounds.xyz * 10;

                float ActivePixelsRatioX = 1 - (ceil(MinBounds.z) - MinBounds.z);
                float ActivePixelsRatioY = 1 - (-MaxBounds.x - floor(-MaxBounds.x));
                float2 ActivePixelsRatio = float2(ActivePixelsRatioX, ActivePixelsRatioY);

                float2 CurrentFrameUV = GetHoudini_SoftVAT_UV(_CurrentFrame, _TotalFrames, ActivePixelsRatio, v.uv2);
                float2 NextFrameUV = GetHoudini_SoftVAT_UV(_CurrentFrame + 1, _TotalFrames, ActivePixelsRatio, v.uv2);

                float4 SampleCurrentPosTex = SAMPLE_TEXTURE2D_LOD(_PositionMap, sampler_point_clamp, CurrentFrameUV, 0);
                float4 SampleNextPosTex = SAMPLE_TEXTURE2D_LOD(_PositionMap, sampler_point_clamp, NextFrameUV, 0);

                float TextureCompare = MaxBounds.z - floor(MaxBounds.z);
                float3 BoundsRange = _MaxBounds.xyz - _MinBounds.xyz;

                float3 LDRCurrentPosTex = BoundsRange * SampleCurrentPosTex.rgb + _MinBounds.xyz;
                float3 LDRNextPosTex = BoundsRange * SampleNextPosTex.rgb + _MinBounds.xyz;

                // [0.5, 1.0] if texture data are in HDR. [0.0, 0.5] if texture data are in LDR.
                float3 CurrentFramePos = (TextureCompare >= 0.5f) ? SampleCurrentPosTex.rgb : LDRCurrentPosTex;
                float3 NextFramePos = (TextureCompare >= 0.5f) ? SampleNextPosTex.rgb : LDRNextPosTex;

                float3 LerpFramePos = lerp(CurrentFramePos, NextFramePos, frac(_CurrentFrame));
                LerpFramePos = _FrameInterpolation > 0 ? LerpFramePos : CurrentFramePos;

                o.vertex.xyz = v.vertex.xyz + LerpFramePos;
                o.vertex.xyz = v.uv2.y <= 0.1f ? 0 : o.vertex.xyz;

                o.vertex = TransformObjectToHClip(o.vertex.xyz);

                float3 CurrentNormal = _UseCompressedNormals ? GetPackedNormal(SampleCurrentPosTex.a) : UnpackNormal(SAMPLE_TEXTURE2D_LOD(_NormalMap, sampler_point_clamp, CurrentFrameUV, 0));
                float3 NextNormal = _UseCompressedNormals ? GetPackedNormal(SampleNextPosTex.a) : UnpackNormal(SAMPLE_TEXTURE2D_LOD(_NormalMap, sampler_point_clamp, NextFrameUV, 0));

                o.normal = _FrameInterpolation ? lerp(CurrentNormal, NextNormal, frac(_CurrentFrame)) : CurrentNormal;
                o.normal = TransformObjectToWorldNormal(o.normal);

                return o;
            }

            half4 frag(VertexOutput i) : SV_Target
            {
                Light light = GetMainLight();
                float LDotN = dot(i.normal, light.direction);
                return half4(LDotN.xxx, 1);
            }
            ENDHLSL
        }
    }
}