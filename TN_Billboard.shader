// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "TN/Billboard"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Vertical("Vertical",Range(0,1))=1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"
        "DisableBatching"="True"}
        LOD 100

        Pass
        {
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

                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Vertical;

            v2f vert (appdata v)
            {
                v2f o; 
                float3 center = float3(0,0,0);
                float3 CameratoLocal =mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1));
                float3 ViewDir = CameratoLocal - center;
                ViewDir.y *= _Vertical;
                ViewDir = normalize(ViewDir);
                float3 fakeDir =  abs(ViewDir.y) > 0.999 ? float3(0,0,1) : float3(0,1,0);
                float3 rightDir = normalize(cross(fakeDir,ViewDir));
                float3 UpDir = normalize(cross(ViewDir,rightDir));
                float3 CenterOffset = v.vertex.xyz - center;
                float3 FinalVertexPos = (CenterOffset.x*rightDir + CenterOffset.y*UpDir +CenterOffset.z*ViewDir);//center + CenterOffset.x*rightDir + CenterOffset.y*UpDir + CenterOffset.z*ViewDir;
                o.vertex = UnityObjectToClipPos(float4(FinalVertexPos.xyz,1)); 
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            } 

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
