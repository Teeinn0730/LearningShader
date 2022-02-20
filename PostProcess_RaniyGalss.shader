Shader "TN/PostProcess_RaniyGalss"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
        _NoiseMap ("NoiseMap", 2D) = "white" {}
        _NoiseIntensity("NoiseIntensity",Range(0,10)) = 1
        _Aspect("Aspect", Vector) = (2,1,0,0)
        _UVTile ("UVTile", Range(0.1,10)) = 1
        _DistortIntensity ("DistortIntensity", Range(-5,5)) = 1
        [MaterialToggle] _FrostedGlass ("FrostedGlass",float) = 0
        _FrostedBlurIntensity("FrostedBlurIntensity",Range(0.01,0.1))= 0.01
        [MaterialToggle] _CircleMask ("CircleMask",float) = 0
        _CircleMaskRange ("CircleMaskRange", Range(0,0.5)) = 0.5
    }
    SubShader
    {
        Tags {  "IgnoreProjector"="True"
                "Queue"="Transparent"
                "RenderType"="PostProcess_RaniyGalss" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Back
        ZWrite Off
        ZTest Always
        GrabPass{
        "_PostProcess_RaniyGalss"
        }
        Pass
        {
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            half inverseLerp(half a,half b,half c){
                return saturate((c-a)/(b-a));
            }
            float N21(float2 p){
                p = frac(p*float2(123.34,345.45));
                p += dot(p,p+34.345);
                return frac(p.x*p.y);
            }

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct VertexOutput
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _PostProcess_RaniyGalss , _NoiseMap;
            float4 _MainTex_ST ,_NoiseMap_ST;
            half _UVTile , _DistortIntensity , _FrostedGlass ,_NoiseIntensity ,_CircleMask , _CircleMaskRange ,_FrostedBlurIntensity;
            half4 _Aspect;

            VertexOutput vert (VertexInput i)
            {
                VertexOutput o;
                o.uv = TRANSFORM_TEX(i.uv, _MainTex);
                half3 FullScreen_Vertex = float3((o.uv.xy*2-1),0);
                #if UNITY_UV_STARTS_AT_TOP
                    FullScreen_Vertex.y *=-1;
                #endif
                o.vertex.xyz = FullScreen_Vertex;
                o.vertex.w = i.vertex.w;
                return o;
            }

            float3 Rainy(float2 OriginalUV , float timeSpd){

                half2 aspect = _Aspect.xy;
                float2 uv = OriginalUV*_UVTile*aspect;
                uv.y += timeSpd*0.25;
                float2 FracUv = frac(uv)-0.5;
                half2 IDMap = floor(uv); 
                half IDNoise = N21(IDMap);
                timeSpd += IDNoise*6.2831;

                float IDDropShape = -sin(timeSpd+sin(timeSpd+sin(timeSpd)*0.5));
                float IDDropShape2 = (FracUv.y - IDDropShape)/aspect.y;
                
                float dropCurve = OriginalUV.y*10;
                float dropSpdX = (IDNoise-0.5)*0.8; //-0.4~0.4
                dropSpdX += (0.4-abs(dropSpdX)) * sin(3*dropCurve)*pow(sin(dropCurve),6)*0.45;

                float dropSpdY = -sin(timeSpd+sin(timeSpd+sin(timeSpd)*0.5))*0.45;
                float dropShapeLerp = pow(FracUv.x-dropSpdX,2);
                dropShapeLerp = lerp(dropShapeLerp,-dropShapeLerp,IDDropShape2);
                dropSpdY += dropShapeLerp;


                float2 dropPos = (FracUv-float2(dropSpdX,dropSpdY));
                half RainyDot = inverseLerp(0.05,0.03,length(dropPos));

                float2 trailPos = (FracUv-float2(dropSpdX,timeSpd*0.25))/aspect;
                trailPos.y = (frac(trailPos.y * 8)-0.5)/8;
                half trail = inverseLerp(0.03,0.01,length(trailPos));
                trail *= inverseLerp(-0.05,0.05,dropPos.y);
                trail *= inverseLerp(0.5,dropSpdY,FracUv.y);

                float fogTrail = inverseLerp(0,0.05,dropPos.y);
                fogTrail *= inverseLerp(0.5,dropSpdY,FracUv.y);
                trail *= fogTrail;
                fogTrail *= inverseLerp(0.05,0.04,abs(dropPos.x));

                float2 offset = RainyDot * dropPos + trail * trailPos  +  0.2* pow(fogTrail,10) * dropPos;
                return float3(offset,fogTrail);
            }

            half4 frag (VertexOutput o) : SV_Target
            {
                half4 NoiseMap = tex2D(_NoiseMap,TRANSFORM_TEX(o.uv,_NoiseMap));
                float timeSpd = fmod(_Time.y,7200);
                half4 col = 0;

                float3 drops = Rainy(o.uv,timeSpd);
                if( _Aspect.z !=0 || _Aspect.w !=0)
                    drops += Rainy(o.uv*_Aspect.z+_Aspect.w,timeSpd);
                
                drops.xy *= NoiseMap.rr;
                half3 ImpactDrops = lerp(drops,NoiseMap.xyz*_NoiseIntensity,0.5);
                drops *= ImpactDrops;
                o.uv += drops.xy*_DistortIntensity;

                half dropsShape = dot(drops,drops);
                half alpha = 1;

                if(_FrostedGlass){
                    const int BlurSample = 8;
                    float rotateSample = N21(o.uv)*6.2831;
                    for (int i = 0; i < BlurSample; i++)
                    {
                        float2 offset = float2(sin(rotateSample),cos(rotateSample))*_FrostedBlurIntensity;
                        float density = frac(sin((i+1)*546)*5424);
                        offset *= density;
                        col += tex2D(_PostProcess_RaniyGalss,o.uv+offset);
                        rotateSample++;
                    }
                    col /= BlurSample;
                    alpha = saturate(1-dropsShape);
                }
                else{
                    col = tex2D(_PostProcess_RaniyGalss,o.uv+drops*_DistortIntensity);
                }

                if(_CircleMask){
                    half2 distanceCircle = distance(half2(0.5,0.5),o.uv);
                    distanceCircle = inverseLerp(_CircleMaskRange,0.5,distanceCircle);
                    alpha *= distanceCircle;
                    //return half4(alpha.xxx,1);
                }
                    
                return half4(col.rgb,alpha);
            }
            ENDCG
        }
    }
}
