Shader "Unlit/TN_DepthSpaceWorld"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DepthRange("DepthRange",Range(-10,10)) = 0 
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"
        "Queue" = "Transparent"}
        LOD 100

        Pass
        {
           
            Blend SrcAlpha OneMinusSrcAlpha
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
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 projPos : TEXCOORD1;
            };

            sampler2D _MainTex , _CameraDepthTexture;
            float4 _MainTex_ST;
            float _DepthRange;

            VertexOutput vert (VertexInput v)
            {
                VertexOutput o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.projPos = ComputeScreenPos(o.vertex);
                COMPUTE_EYEDEPTH(o.projPos.z);
                return o;
            }

            fixed4 frag (VertexOutput o) : SV_Target
            {
                //利用ScreenSpace空間下的屏幕座標先轉成NDC，再把向量轉成值並用逆矩陣轉換回世界空間。
                float4 NDC = (o.projPos / o.projPos.w) * 2 - 1 ;
                float3 ClipSpacePos = float3( NDC.x , NDC.y , NDC.z ) * _ProjectionParams.z; //先從NDC轉換成ClipSpace空間。//注意這裡的NDC.z值，其實就是NDC下的o.vertex.z值，但是在ClipSpace也就是ViewSpace的情況下，在ViewSpace的空間裡面向攝影機的Z軸才是正的，與平常的右手坐標系是相反的。在此並須反轉Z值才會出現正確的顯示。這裡的NDC.z並未乘上負值，是因為在前面就已經利用函數COMPUTE_EYEDEPTH(o.projPos.z)反轉過了，所以在這裡就可以正常使用。
                float3 ProjSpacePos= mul( unity_CameraInvProjection , ClipSpacePos.xyzz );
                //利用屏幕空間的座標乘以深度值，便可以讓座標的像素也有正確的深度值惹。
                float DepthTex = UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture,o.projPos));
                float3 DepthViewDir = ProjSpacePos*Linear01Depth(DepthTex);
                //在轉換到世界空間下，便可以拿來做使用。
                float3 DepthWorldSpaceDir = mul(UNITY_MATRIX_I_V,float4(DepthViewDir,1));
                //以上為用深度值重建世界座標的算法。
                float fog = lerp(0.5,0,saturate(DepthWorldSpaceDir.y+_DepthRange));
                return fixed4(fog.xxx,fog);
            }
            ENDCG
        }
    }
}
