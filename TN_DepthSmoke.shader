Shader "TN/DepthSmoke"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NoiseTex ("NoiseTex", 3D) = "white" {}
        _WorldStructXYZ ("WorldStructXYZ", Vector) = (1,1,1,1)
        
    }
    SubShader
    {

        Pass
        {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            #include "UnityCG.cginc"
            #include "Lighting.cginc"


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float2 uv_depth : TEXCOORD1;
                float4 interpolatedRay : TEXCOORD2;
                float4 projPos : TEXCOORD3;
            };
            float4x4 _FrustumCornersRay;
			float4 _WorldStructXYZ;
		    sampler2D _MainTex;
		    half4 _MainTex_TexelSize;
		    sampler2D _CameraDepthTexture;
		    half _FogDensity;
		    fixed4 _FogColor;
		    float _FogStart;
		    float _FogEnd;
		    sampler3D _NoiseTex;
		    half _FogXSpeed;
		    half _FogYSpeed;
		    half _NoiseAmount;
            v2f vert(appdata_img v) {
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.projPos = ComputeScreenPos(o.vertex);
			COMPUTE_EYEDEPTH(o.projPos.z);
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
			
			int index = 0;
			if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5) {
				index = 0;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5) {
				index = 1;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5) {
				index = 2;
			} else {
				index = 3;
			}
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				index = 3 - index;
			#endif
			
			o.interpolatedRay = _FrustumCornersRay[index];
				 	 
			return o;
		}
		
		fixed4 frag(v2f i) : SV_Target {
			float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
			float linearDepth2 = (SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
			float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;
			float3 speed = _Time.y * float3(_WorldStructXYZ.x, _WorldStructXYZ.y,_WorldStructXYZ.z);
			float noise = (tex3D(_NoiseTex, (worldPos.xyz/_NoiseAmount) + speed).r) ;

			float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart); 
			fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));

			float sceneZ = max(0,LinearEyeDepth (UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)))) );   
            float partZ = max(0,i.projPos.z );
			float Depth = saturate((sceneZ-partZ)/_WorldStructXYZ.w);

			//return fixed4(Depth.xxx,1);

			fixed4 finalColor = tex2D(_MainTex, i.uv);
			float3 FogColor =_FogColor.rgb; 
			float fogDensity2 =1;
            for (int i = 0; i < 5; i++)
            {
				fogDensity2 *= fogDensity;
                FogColor += 0.1*fogDensity;
            }
			FogColor = lerp(FogColor.rgb,_LightColor0.xyz,Depth);
			finalColor.rgb = lerp(finalColor.rgb, FogColor.rgb, fogDensity);
			
			return fixed4(finalColor.xyz,1);
		}
            ENDCG
        }
    }
}
