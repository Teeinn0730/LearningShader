Shader "Unlit/TN_PostProcessing"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Brightness("Brightness",Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZTest Always
            ZWrite Off
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv[9] : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            half _Brightness;


            half Sobel(v2f i){
                const half Gx[9]={-1,-2,-1,
                                                0,0,0,
                                                1,2,1};
                const half Gy[9]={-1,0,1,
                                                -2,0,2,
                                                -1,0,1};
                half texColor ;
                half edgeX = 0;
                half edgeY = 0;
                for(int it = 0 ; it<9 ; it++){
                    texColor=dot(tex2D(_MainTex,i.uv[it]),half3(0.3,0.59,0.11));
                    edgeX += texColor * Gx[it];
                    edgeY += texColor * Gy[it];
                }
                half edge = 1-(abs(edgeX)+abs(edgeY));//1- abs(edgeX)-abs(edgeY);
                return edge;
            }



            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                //o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                half2 uv = v.uv;
                o.uv[0]= uv + _MainTex_TexelSize.xy*half2(-1,-1);
                o.uv[1]= uv + _MainTex_TexelSize.xy*half2(0,-1);
                o.uv[2]= uv + _MainTex_TexelSize.xy*half2(1,-1);
                o.uv[3]= uv + _MainTex_TexelSize.xy*half2(-1,0);
                o.uv[4]= uv + _MainTex_TexelSize.xy*half2(0,0);
                o.uv[5]= uv + _MainTex_TexelSize.xy*half2(1,0);
                o.uv[6]= uv + _MainTex_TexelSize.xy*half2(-1,1);
                o.uv[7]= uv + _MainTex_TexelSize.xy*half2(0,1);
                o.uv[8]= uv + _MainTex_TexelSize.xy*half2(1,1);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half edge = Sobel(i);
                half4 col = lerp(fixed4(0,0,0,1),tex2D(_MainTex,i.uv[4]),edge);
                half4 backgroundColor = lerp(0,1,edge);
                return lerp(col,backgroundColor,_Brightness);
            }
            ENDCG
        }
    }
}
