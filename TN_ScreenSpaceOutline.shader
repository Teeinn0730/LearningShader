Shader "Unlit/TN_ScreenSpaceOutline"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Distance ("Distance", Float) = 1
        _Sensitive ("Sensitive", Vector) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"
        "Queue" = "Transparent"}
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
            #include "UnityCG.cginc"

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VertexOutput
            {
                float4 vertex : SV_POSITION;
                float2 uv[5] : TEXCOORD0;
            };

            sampler2D _MainTex, _CameraDepthNormalsTexture;
            float4 _MainTex_ST , _MainTex_TexelSize , _Sensitive;
            float _Distance;
            

            half CheckEdge (float4 C1 , float4 C2){
                half2 C1_Center = C1.xy;
                half2 C2_Center = C2.xy;
                float C1_Depth =DecodeFloatRG(C1.zw);
                float C2_Depth =DecodeFloatRG(C2.zw);

                half2 DiffNormal = abs(C1_Center-C2_Center)*_Sensitive.x;
                int isSameNormal = (DiffNormal.x + DiffNormal.y) < 0.1;
                float DiffDepth = abs(C1_Depth-C2_Depth)*_Sensitive.y;
                int isSameDpeth = DiffDepth < 0.1 * C1_Depth;

                return isSameNormal * isSameDpeth ;
            }

 

            VertexOutput vert (VertexInput v)
            {
                VertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                #if UNITY_UV_STARTS_AT_TOP
                    if(_MainTex_TexelSize.y < 0)
                        v.uv.y = 1- v.uv.y;
                #endif
                o.uv[0] = v.uv;
                o.uv[1] = v.uv + _MainTex_TexelSize.xy * half2(1,1) * _Distance;
                o.uv[2] = v.uv + _MainTex_TexelSize.xy * half2(-1,-1) * _Distance;
                o.uv[3] = v.uv + _MainTex_TexelSize.xy * half2(-1,1) * _Distance;
                o.uv[4] = v.uv + _MainTex_TexelSize.xy * half2(1,-1) * _Distance;
                
                return o;
            }

            fixed4 frag (VertexOutput o) : SV_Target
            {
                float4 sample1 = tex2D(_CameraDepthNormalsTexture,o.uv[1]);
                float4 sample2 = tex2D(_CameraDepthNormalsTexture,o.uv[2]);
                float4 sample3 = tex2D(_CameraDepthNormalsTexture,o.uv[3]);
                float4 sample4 = tex2D(_CameraDepthNormalsTexture,o.uv[4]);


                half edge = 1;
                edge *= CheckEdge(sample1,sample2);
                edge *= CheckEdge(sample3,sample4);

                float4 ScreenCol = tex2D(_MainTex,o.uv[0]);
                float3 col = lerp(0.1*ScreenCol,ScreenCol,edge);
                return fixed4(col,1);
            }
            ENDCG
        }
    }
}
