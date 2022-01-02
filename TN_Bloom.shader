Shader "TN/Bloom"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OriginalTex ("OriginalTex", 2D) = "white" {}
        _BlurSize("BlurSize",Float) = 1
        _Threshold("Threshold",Range(0,1)) = 0.9
        _BloomLightIntensity("BloomLightIntensity",Range(0,5)) = 1
    }
    SubShader
    {
        CGINCLUDE
            sampler2D _MainTex , _OriginalTex;
            half4 _MainTex_TexelSize;
            half _Threshold , _BloomLightIntensity;

            struct Vertexinput{
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            half InverseLerp(half a,half b){
                return saturate((1-a)/(b-a));
            }
            half3 Overlay (float3 a , float3 b){
                return saturate(( b > 0.5 ? (1.0-(1.0-2.0*(b-0.5))*(1.0-a)) : (2.0*b*a) ));
            }
            float3 Screen (float3 a , float3 b){
                return saturate((1.0-(1.0-a)*(1.0-b)));
            }

            VertexOutput vertThreshold (Vertexinput i){
                VertexOutput o ;
                o.pos = UnityObjectToClipPos(i.pos);
                o.uv.xy = i.uv.xy;
                return o;
            }
            half4 fragThreshold (VertexOutput o) : SV_TARGET{
                half4 col = tex2D(_MainTex,o.uv.xy);
                half col_Desaturate = dot(col.rgb,half3(0.3,0.59,0.11));
                //col_Desaturate = InverseLerp(_Threshold,col_Desaturate);
                col_Desaturate =max(0,(col_Desaturate-_Threshold));
                col.rgb *= col_Desaturate;
                return half4(col.rgb,1);
            }
            half4 fragBloom (VertexOutput o) : SV_TARGET{
                half4 col = tex2D(_MainTex,o.uv.xy);
                half4 OriginalCol = tex2D(_OriginalTex,o.uv.xy);
                col *= _BloomLightIntensity;
                col = saturate(col);
                col.rgb = Screen(col.rgb,OriginalCol.rgb);
                return half4(col.rgb,1);
            }
        ENDCG

        Tags { "RenderType"="Opaque" }

        Pass
        {
            ZTest Always
            ZWrite Off
            Name "Bloom_Threshold"
            CGPROGRAM
            #pragma vertex vertThreshold
            #pragma fragment fragThreshold
            ENDCG
        }

        UsePass"TN/_GaussingBlur/GAUSSINGBLUR_VERTICAL"

        UsePass"TN/_GaussingBlur/GAUSSINGBLUR_HORIZONTAL"

        Pass{
             ZTest Always
            ZWrite Off
            
            Name "Bloom_Final"
            CGPROGRAM
            #pragma vertex vertThreshold
            #pragma fragment fragBloom
            ENDCG
        }
    }
    Fallback Off
}
