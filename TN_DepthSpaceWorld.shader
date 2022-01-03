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
                //�Q��ScreenSpace�Ŷ��U���̹��y�Х��নNDC�A�A��V�q�ন�Ȩåΰf�x�}�ഫ�^�@�ɪŶ��C
                float4 NDC = (o.projPos / o.projPos.w) * 2 - 1 ;
                float3 ClipSpacePos = float3( NDC.x , NDC.y , NDC.z ) * _ProjectionParams.z; //���qNDC�ഫ��ClipSpace�Ŷ��C//�`�N�o�̪�NDC.z�ȡA���N�ONDC�U��o.vertex.z�ȡA���O�bClipSpace�]�N�OViewSpace�����p�U�A�bViewSpace���Ŷ��̭��V��v����Z�b�~�O�����A�P���`���k�⧤�Шt�O�ۤϪ��C�b���ö�����Z�Ȥ~�|�X�{���T����ܡC�o�̪�NDC.z�å����W�t�ȡA�O�]���b�e���N�w�g�Q�Ψ��COMPUTE_EYEDEPTH(o.projPos.z)����L�F�A�ҥH�b�o�̴N�i�H���`�ϥΡC
                float3 ProjSpacePos= mul( unity_CameraInvProjection , ClipSpacePos.xyzz );
                //�Q�Ϋ̹��Ŷ����y�Э��H�`�׭ȡA�K�i�H���y�Ъ������]�����T���`�׭ȷS�C
                float DepthTex = UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture,o.projPos));
                float3 DepthViewDir = ProjSpacePos*Linear01Depth(DepthTex);
                //�b�ഫ��@�ɪŶ��U�A�K�i�H���Ӱ��ϥΡC
                float3 DepthWorldSpaceDir = mul(UNITY_MATRIX_I_V,float4(DepthViewDir,1));
                //�H�W���β`�׭ȭ��إ@�ɮy�Ъ���k�C
                float fog = lerp(0.5,0,saturate(DepthWorldSpaceDir.y+_DepthRange));
                return fixed4(fog.xxx,fog);
            }
            ENDCG
        }
    }
}
