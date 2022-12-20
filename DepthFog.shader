Shader "Unlit/DepthFog" {
    Properties {
        //_mipTex ("Texture", 2D) = "white" {}
        _DepthSlider ("DepthSlider", Float) = 1
        _CameraToFog ("CameraToFog", Float) = 1
        _FogPower ("FogPower", Float) = 1
    }
    SubShader {
        Tags { "RenderType" = "Transparent" }

        Cull Off
        ZWrite Off
        ZTest Always

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct VertexInput {
                float4 vertex : POSITION;
            };

            struct VertexOutput {
                float4 vertex : SV_POSITION;
                float4 projPos : TEXCOOR0;
            };

            sampler2D _MainTex, _CameraDepthTexture, DepthFogTex ,_ToneMap;
            float4 _MainTex_ST, _MainTex_TexelSize;
            half _DepthSlider, _CameraToFog , _FogPower;
            float4x4 _InverseView;

            VertexOutput vert(VertexInput v) {
                VertexOutput o;
                o.vertex = (v.vertex);
                o.projPos = ComputeScreenPos(o.vertex);
                COMPUTE_EYEDEPTH(o.projPos.z);

                return o;
            }

            fixed4 frag(VertexOutput o) : SV_Target {
                fixed2 ScreenUV = o.projPos.xy / o.projPos.w;
                fixed4 col = tex2D(_MainTex, ScreenUV);
                float depthTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, ScreenUV);
                float sceneZ = max(0,LinearEyeDepth(depthTex)) - _CameraToFog;
                sceneZ = saturate(sceneZ / _DepthSlider);
                half3 FogColor = sceneZ * _LightColor0.rgb ;

                const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
                const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
                const float isOrtho = unity_OrthoParams.w;
                const float near = _ProjectionParams.y;
                const float far = _ProjectionParams.z;

                float d = depthTex;
                #if defined(UNITY_REVERSED_Z)
                        d = 1 - d;
                #endif
                float zOrtho = lerp(near, far, d);
                float zPers = near * far / lerp(far, near, d);
                float vz = lerp(zPers, zOrtho, isOrtho);

                float3 vpos = float3((ScreenUV  - p13_31) / p11_22 * lerp(vz, 1, isOrtho), -vz);
                float4 wpos = mul(_InverseView, float4(vpos, 1));
                wpos /= _ProjectionParams.z;
                wpos = abs(wpos);
                wpos = 1-saturate(wpos);
                wpos = pow(wpos,_FogPower); // 讓霧效更集中在水平線上。

                float4 ToneMapLight = tex2D(_ToneMap,(wpos*sceneZ).yy); // 讓霧效以ToneMap顏色做漸層。
                col.rgb = lerp(col.rgb, FogColor*ToneMapLight, sceneZ*wpos.y);
                return fixed4(col.rgb, 1);
            }
            ENDCG
        }
    }
}
//https://github.com/FinGameWorks/DepthToWorldPos