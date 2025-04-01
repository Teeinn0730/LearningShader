Shader "Unlit/Rigid_VAT"
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
        SamplerState sampler_point_clamp, sampler_point_repeat;

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
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float2 uv3 : TEXCOORD3;
                float3 vertexColor : COLOR;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
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

            float4 Decode_Quaternion(in float3 XYZ, in float MaxComponent)
            {
                float w = sqrt(1.0 - pow(XYZ.x, 2) - pow(XYZ.y, 2) - pow(XYZ.z, 2));
                float4 q = float4(0, 0, 0, 1);

                switch (MaxComponent)
                {
                case 0:
                    q = float4(XYZ.x, XYZ.y, XYZ.z, w);
                    break;
                case 1:
                    q = float4(w, XYZ.y, XYZ.z, XYZ.x);
                    break;
                case 2:
                    q = float4(XYZ.x, -w, XYZ.z, -XYZ.y);
                    break;
                case 3:
                    q = float4(XYZ.x, XYZ.y, -w, -XYZ.z);
                    break;
                default:
                    q = float4(XYZ.x, XYZ.y, XYZ.z, w);
                    break;
                }

                return q;
            }


            VertexOutput vert(VertexInput v)
            {
                VertexOutput o = (VertexOutput)0;

                // Piece Pivot
                float3 PiecePivot = float3(-v.uv2.x, v.uv3.x, 1 - v.uv3.y);
                PiecePivot = v.vertex.xyz - PiecePivot;

                // Bounds
                float3 MaxBounds = _MaxBounds.xyz * 10;
                float3 MinBounds = _MinBounds.xyz * 10;

                float ActivePixelsRatioX = 1 - (ceil(MinBounds.z) - MinBounds.z);
                float ActivePixelsRatioY = 1 - (-MaxBounds.x - floor(-MaxBounds.x));
                float2 ActivePixelsRatio = float2(ActivePixelsRatioX, ActivePixelsRatioY);

                // Frame UV Shared Data
                float CurrentFrame = floor(_CurrentFrame);
                float InterpolatedFrame = frac(_CurrentFrame);
                float AverageFrames = 1 / _TotalFrames;
                bool TextureFormat = (MaxBounds.z - floor(MaxBounds.z)) >= 0.5f;
                float3 BoundsLength = _MaxBounds.rgb - _MinBounds.rgb;
                float MaxRPF = 1 / (1 - (-MinBounds.x - floor(-MinBounds.x))); // revolutions per frame

                // This Frame UV
                float2 ThisFrameUV = 0;
                ThisFrameUV.r = v.uv1.x * ActivePixelsRatio.x;
                ThisFrameUV.g = CurrentFrame % _TotalFrames * AverageFrames * ActivePixelsRatio.y;
                ThisFrameUV.g += (1 - v.uv1.y) * ActivePixelsRatio.y;
                ThisFrameUV.g = 1 - ThisFrameUV.g;

                // Next Frame UV
                float2 NextFrameUV = 0;
                NextFrameUV.r = v.uv1.x * ActivePixelsRatio.x;
                NextFrameUV.g = (CurrentFrame + 1) % _TotalFrames * AverageFrames * ActivePixelsRatio.y;
                NextFrameUV.g += (1 - v.uv1.y) * ActivePixelsRatio.y;
                NextFrameUV.g = 1 - NextFrameUV.g;

                // Sample Frame Position
                float4 SampleThisFramePosition = SAMPLE_TEXTURE2D_LOD(_PositionMap, sampler_point_repeat, ThisFrameUV, 0);
                float4 SampleNextFramePosition = SAMPLE_TEXTURE2D_LOD(_PositionMap, sampler_point_repeat, NextFrameUV, 0);
                
                float3 ThisFramePosition = TextureFormat ? SampleThisFramePosition.rgb : SampleThisFramePosition.rgb * BoundsLength + _MinBounds.rgb;
                float3 NextFramePosition = TextureFormat ? SampleNextFramePosition.rgb : SampleNextFramePosition.rgb * BoundsLength + _MinBounds.rgb;
                
                // Sample Frame Rotation
                float4 SampleThisFrameRotation = SAMPLE_TEXTURE2D_LOD(_RotationMap, sampler_point_repeat, ThisFrameUV, 0);
                float4 SampleNextFrameRotation = SAMPLE_TEXTURE2D_LOD(_RotationMap, sampler_point_repeat, NextFrameUV, 0);
                SampleThisFrameRotation = TextureFormat ? SampleThisFrameRotation : (SampleThisFrameRotation - 0.5f) * 2;
                SampleNextFrameRotation = TextureFormat ? SampleNextFrameRotation : (SampleNextFrameRotation - 0.5f) * 2;

                float4 DecodeThisFrameRotation = Decode_Quaternion(SampleThisFrameRotation.rgb, floor(SampleThisFramePosition.a * 4));
                float4 DecodeNextFrameRotation = Decode_Quaternion(SampleNextFrameRotation.rgb, floor(SampleNextFramePosition.a * 4));

                // Multi-RPF Quaternion Slerp
                float ThisFrameQuaternion_Alpha = TextureFormat ? abs(SampleThisFrameRotation.a) : abs(SampleThisFrameRotation.a) * MaxRPF;
                float ThisFrameQuaternion_Alpha_Slerp = frac(ThisFrameQuaternion_Alpha) * 0.5f;
                float ThisFrameQuaternion_Alpha_Interpolated_Slerp = frac(ThisFrameQuaternion_Alpha * InterpolatedFrame) * 0.5f;
                float4 ThisFrameQuaternion = sin((ThisFrameQuaternion_Alpha_Slerp - ThisFrameQuaternion_Alpha_Interpolated_Slerp) * TWO_PI) * DecodeThisFrameRotation;
                float4 NextFrameQuaternion = sin(ThisFrameQuaternion_Alpha_Interpolated_Slerp * TWO_PI) * (DecodeNextFrameRotation * sign(SampleThisFrameRotation.a));
                float4 FrameQuaternion = (ThisFrameQuaternion + NextFrameQuaternion) / sin(ThisFrameQuaternion_Alpha_Slerp * TWO_PI);
                FrameQuaternion = normalize(FrameQuaternion);

                float4 RotationOS = SampleThisFrameRotation.a != 0 ? FrameQuaternion : DecodeThisFrameRotation;
                RotationOS = _FrameInterpolation ? RotationOS : DecodeThisFrameRotation;

                // Rotate Vector by Quaternion
                float3 FixPosWithRotation = cross(RotationOS.rgb, PiecePivot) + (PiecePivot * RotationOS.w);
                FixPosWithRotation = cross(RotationOS.rgb, FixPosWithRotation) * 2;
                FixPosWithRotation += PiecePivot;

                // Interpolated Frame Position
                float3 PositionOS = _FrameInterpolation ? lerp(ThisFramePosition, NextFramePosition, InterpolatedFrame) : ThisFramePosition;
                PositionOS += FixPosWithRotation;

                PositionOS = (CurrentFrame % _TotalFrames) != 1 ? PositionOS : v.vertex.xyz;

                o.vertex = TransformObjectToHClip(PositionOS);

                // Normal Vector
                float3 FixNormalVector = v.normal * RotationOS.w + cross(RotationOS.xyz, v.normal);
                FixNormalVector = cross(RotationOS.xyz, FixNormalVector);
                FixNormalVector *= 2;
                FixNormalVector += v.normal;
                FixNormalVector = normalize(FixNormalVector);
                o.normal = TransformObjectToWorldNormal(FixNormalVector);

                float3 FixTangentVector = v.tangent.xyz * RotationOS.a + cross(RotationOS.xyz, v.tangent.xyz);
                FixTangentVector = cross(RotationOS.rgb, FixTangentVector);
                FixTangentVector *= 2;
                FixTangentVector += v.tangent.xyz;
                FixTangentVector = normalize(FixTangentVector);

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