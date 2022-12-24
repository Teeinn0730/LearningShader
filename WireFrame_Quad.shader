Shader "Unlit/WireFrame_Quad" {
    Properties {
        _MainTex ("Texture", 2D) = "white" { }
        _WireColor ("Color", Color) = (1, 1, 1, 1)
        _WireThickness ("WireThickness", range(0, 10)) = 0.1
    }
    SubShader {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
        LOD 100

        Pass {
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Back
            ZTest Always
            ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct g2f //TriangleStream
            {
                float4 vertex : SV_POSITION;
                float3 barycentric : TEXCOORD0;
                float2 uv : TEXCOORD1;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST, _WireColor;
            half _WireThickness;

            v2f vert(appdata v) {
                v2f o;
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.vertex = v.vertex;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            [maxvertexcount(3)]
            void geom(triangle v2f IN[3], inout TriangleStream<g2f> triStream) {
                float v0 = length(IN[1].vertex - IN[2].vertex);
                float v1 = length(IN[0].vertex - IN[2].vertex);
                float v2 = length(IN[0].vertex - IN[1].vertex);
                float3 modifier = float3(0, 0, 0);
                if ((v0 > v1) && (v0 > v2))
                    modifier = float3(1, 0, 0);
                else if ((v1 > v0) && (v1 > v2))
                    modifier = float3(0, 1, 0);
                else if ((v2 > v0) && (v2 > v1))
                    modifier = float3(0, 0, 1);

                g2f o;
                o.vertex = UnityObjectToClipPos(IN[0].vertex);
                o.barycentric = float3(1, 0, 0) + modifier ;
                o.uv = IN[0].uv;
                triStream.Append(o);
                o.vertex = UnityObjectToClipPos(IN[1].vertex);
                o.barycentric = float3(0, 1, 0) + modifier ;
                o.uv = IN[1].uv;
                triStream.Append(o);
                o.vertex = UnityObjectToClipPos(IN[2].vertex);
                o.barycentric = float3(0, 0, 1) + modifier ;
                o.uv = IN[2].uv;
                triStream.Append(o);
            }

            fixed4 frag(g2f o) : SV_Target {
                float3 unitWidth = fwidth(o.barycentric);
                float3 aliased = smoothstep(0, unitWidth * _WireThickness, o.barycentric);
                float wire = 1 - min(aliased.x, min(aliased.y, aliased.z));
                //float wire = 1 - min(o.barycentric.x, min(o.barycentric.y, o.barycentric.z));
                //clip(wire - _WireThickness);
                fixed4 col = tex2D(_MainTex, o.uv);
                col.rgb = lerp(col.rgb, _WireColor.rgb, wire);
                return fixed4(col);
            }
            ENDCG
        }
    }
}