Shader "TN/_GaussingBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BlurSize("BlurSize",Float) = 1
    }
    SubShader
    {
        CGINCLUDE
            sampler2D _MainTex;
            half4 _MainTex_TexelSize;
            float _BlurSize;

            struct Vertexinput{
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Vertexoutput {
                float4 pos : SV_POSITION;
                float2 uv[5] : TEXCOORD0;
            };

            Vertexoutput vertVertical (Vertexinput i){
                Vertexoutput o ;
                o.pos = UnityObjectToClipPos(i.pos);
                float2 uv = i.uv;
                o.uv[0] = uv;
                o.uv[1] = uv + float2(0,_MainTex_TexelSize.y * 1)*_BlurSize;
                o.uv[2] = uv - float2(0,_MainTex_TexelSize.y * 1)* _BlurSize;
                o.uv[3] = uv + float2(0,_MainTex_TexelSize.y * 2)*_BlurSize;
                o.uv[4] = uv - float2(0,_MainTex_TexelSize.y * 2)* _BlurSize;

                return o;
            }

            Vertexoutput vertHorizon (Vertexinput i){
                Vertexoutput o ;
                o.pos = UnityObjectToClipPos(i.pos);
                float2 uv = i.uv;
                o.uv[0] = uv;
                o.uv[1] = uv + float2(_MainTex_TexelSize.y * 1,0)*_BlurSize;
                o.uv[2] = uv - float2(_MainTex_TexelSize.y * 1,0)* _BlurSize;
                o.uv[3] = uv + float2(_MainTex_TexelSize.y * 2,0)*_BlurSize;
                o.uv[4] = uv - float2(_MainTex_TexelSize.y * 2,0)* _BlurSize;

                return o;
            }

            half4 frag (Vertexoutput o ) : SV_TARGET{
                float weight[3] = {0.4026,0.2442,0.0545};
                fixed3 sum = tex2D(_MainTex,o.uv[0]).rgb*weight[0];

                for (int it = 1; it < 3; it++)
                {
                    sum += tex2D(_MainTex,o.uv[it*2-1]).rgb*weight[it];
                    sum += tex2D(_MainTex,o.uv[it*2]).rgb*weight[it];
                }
                return half4(sum.rgb,1);
            }
        ENDCG

        ZTest Always 
        ZWrite Off

        Pass
        {
            Name "GaussingBlur_Vertical"
            CGPROGRAM
            #pragma vertex vertVertical
            #pragma fragment frag
            ENDCG
        }
        Pass
        {
            Name "GaussingBlur_Horizontal"
            CGPROGRAM
            #pragma vertex vertHorizon
            #pragma fragment frag
            ENDCG
        }
    }
}
