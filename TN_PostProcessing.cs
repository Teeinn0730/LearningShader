using JetBrains.Annotations;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Configuration;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering.Universal;

public class TN_PostProcessing : TN_PostEffectBase
{
    public Shader shader ;
    private Material PriMat;
    public Material PubMat
    {
        get
        {
            PriMat = CheckShaderAndMat(shader,PriMat);
            return PriMat;
        }
    }
    public bool posteffect = false;
    public enum WhichPostProccesing
    {
        EdgeDetch ,
        Blur,
        Bloom,
        ScreenSpaceOutline,
        DepthSmoke
    }
    public WhichPostProccesing ChooseOne = new WhichPostProccesing();

    [Header("BrightTest")]
    [Range(0,1)] public float Brightness = 1;
    [Header("Blur")]
    [Range(1,10)] public int DownSample = 1;
    public int BlurIntensity = 5;
    public float blurSpread = 0.6f;
    [Range(0,1)] public float Threshold = 0.9f;
    [Range(0,5)] public int BloomLightIntensity = 1;
    [Header("ScreenSpaceOutline")]
    public float Distance = 1; //every 0.5f can improve the distance , cuz the texelsize mininum stpe is 0.5.
    public Vector4 Sensitive = new Vector4(1,1,0,0);
    [Header("DepthSmoke")]
    public Vector4 WorldStructXYZ = new Vector4(1,1,0,0);
    //public GameObject ScreenQuad;
    public Texture3D NoiseTex;
    [Range(0.1f, 3.0f)]
	public float fogDensity = 1.0f;
	public Color fogColor = Color.white;
	public float fogStart = 0.0f;
	public float fogEnd = 2.0f;
	[Range(-0.5f, 0.5f)]
	public float fogXSpeed = 0.1f;
	[Range(-0.5f, 0.5f)]
	public float fogYSpeed = 0.1f;
	public float noiseAmount = 1.0f;

    private void OnEnable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
    }
    private void OnDisable()
    {
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.None;
        //DestroyImmediate(ScreenQuad);
    }

   
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        
        //OnRenderImage只能使用在Built_in管線當中，URP及HDRP請使用ScriptableRenderPass API。
        //OnRenderImage is not supported in the Scriptable Render Pipeline. To create custom fullscreen effects in the Universal Render Pipeline (URP), use the ScriptableRenderPass API. To create custom fullscreen effects in the High Definition Render Pipeline (HDRP), use a Fullscreen Custom Pass.
        //https://docs.unity3d.com/ScriptReference/Camera.OnRenderImage.html
        if(posteffect == true)
            switch (ChooseOne)
            {
                case WhichPostProccesing.EdgeDetch:
                        shader = Shader.Find("Unlit/TN_PostProcessing");
                        EdgeDetch(ref source, ref destination);
                    break;
                case WhichPostProccesing.Blur:
                        shader = Shader.Find("TN/_GaussingBlur");
                        GaussingBlur(ref source,ref destination);
                    break;
                case WhichPostProccesing.Bloom:
                        shader = Shader.Find("TN/Bloom");
                        Bloom(ref source,ref destination);
                    break;
                case WhichPostProccesing.ScreenSpaceOutline:
                        shader = Shader.Find("Unlit/TN_ScreenSpaceOutline");
                        ScreenSpaceEdge(ref source,ref destination);
                    break;
                case WhichPostProccesing.DepthSmoke:
                        shader = Shader.Find("TN/DepthSmoke");
                        DepthSmoke(ref source,ref destination);
                    break;
                default:
                    break;
            }
        else 
            Graphics.Blit(source, destination);
    }

    public void EdgeDetch(ref RenderTexture source, ref RenderTexture destination)
    {
        if (PubMat != null)
        {
            PubMat.SetFloat("_Brightness", Brightness);
            Graphics.Blit(source, destination, PubMat);
            Debug.Log("sucess");
        }
        else
        {
            Graphics.Blit(source,destination);
            Debug.Log("Fail");
        }
    }

    public void GaussingBlur(ref RenderTexture source, ref RenderTexture destination)
    {
        if (PubMat != null)
        {
            int RenderTexWidth = source.width / DownSample;
            int RenderTexHeight = source.height / DownSample;
            RenderTexture buffer = RenderTexture.GetTemporary(RenderTexWidth,RenderTexHeight,0);
            buffer.filterMode = FilterMode.Bilinear;
            Graphics.Blit(source,buffer);
            for (int i = 0; i < BlurIntensity; i++)
            {
                PubMat.SetFloat("_BlurSize",1+i*blurSpread);
                RenderTexture buffer2 = RenderTexture.GetTemporary(RenderTexWidth,RenderTexHeight,0);
                Graphics.Blit(buffer,buffer2,PubMat,0); 
                RenderTexture.ReleaseTemporary(buffer);
                buffer = buffer2;
                buffer2 = RenderTexture.GetTemporary(RenderTexWidth,RenderTexHeight,0);
                Graphics.Blit(buffer,buffer2,PubMat,1);
                RenderTexture.ReleaseTemporary(buffer);
                buffer = buffer2;
                //RenderTexture.ReleaseTemporary(buffer2);
            }
            Graphics.Blit(buffer,destination);
            RenderTexture.ReleaseTemporary(buffer);
            Debug.Log("Succes");
        }
        else
        {
            Graphics.Blit(source,destination);
            Debug.Log("Fail");
        }
    }

    public void Bloom(ref RenderTexture source, ref RenderTexture destination)
    {
        if (PubMat != null)
        {
            int RenderTexWidth = source.width / DownSample;
            int RenderTexHeight = source.height / DownSample;
            RenderTexture buffer = RenderTexture.GetTemporary(RenderTexWidth,RenderTexHeight,0);
            buffer.filterMode = FilterMode.Bilinear;
            Graphics.Blit(source,buffer,PubMat,0);
            PubMat.SetTexture("_OriginalTex",source);
            for (int i = 0; i < BlurIntensity; i++)
            {
                PubMat.SetFloat("_BlurSize",1+i*blurSpread);
                RenderTexture buffer2 = RenderTexture.GetTemporary(RenderTexWidth,RenderTexHeight,0);
                Graphics.Blit(buffer,buffer2,PubMat,1); 
                RenderTexture.ReleaseTemporary(buffer);
                buffer = buffer2;
                buffer2 = RenderTexture.GetTemporary(RenderTexWidth,RenderTexHeight,0);
                Graphics.Blit(buffer,buffer2,PubMat,2);
                RenderTexture.ReleaseTemporary(buffer);
                buffer = buffer2;
                //RenderTexture.ReleaseTemporary(buffer2);
            }
            PubMat.SetFloat("_Threshold",Threshold);
            PubMat.SetFloat("_BloomLightIntensity",BloomLightIntensity);
            Graphics.Blit(buffer,destination,PubMat,3);
            RenderTexture.ReleaseTemporary(buffer);
            Debug.Log("Succes");
        }
        else
        {
            Graphics.Blit(source,destination);
            Debug.Log("Fail");
        }
    }
    public void ScreenSpaceEdge(ref RenderTexture source, ref RenderTexture destination)
    {
        if (PubMat != null)
        {
            //PubMat.SetFloat("_Brightness", Brightness);
            PubMat.SetFloat("_Distance",Distance);
            PubMat.SetVector("_Sensitive",Sensitive);
            Graphics.Blit(source, destination, PubMat);
            Debug.Log("sucess");
        }
        else
        {
            Graphics.Blit(source,destination);
            Debug.Log("Fail");
        }
    }
    private Camera myCamera;
	public Camera Camera {
		get {
			if (myCamera == null) { 
				myCamera = GetComponent<Camera>();
			}
			return myCamera;
		}
	}

	private Transform myCameraTransform;
	public Transform CameraTransform {
		get {
			if (myCameraTransform == null) {
				myCameraTransform = Camera.transform;
			}
			
			return myCameraTransform;
		}
	}
    public void DepthSmoke(ref RenderTexture source, ref RenderTexture destination)
    {   
        
        if (PubMat != null)
        {
           Matrix4x4 frustumCorners = Matrix4x4.identity;
			
			float fov = Camera.fieldOfView;
			float near = Camera.nearClipPlane;
			float aspect = Camera.aspect;
			
			float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
			Vector3 toRight = CameraTransform.right * halfHeight * aspect;
			Vector3 toTop = CameraTransform.up * halfHeight;
			
			Vector3 topLeft = CameraTransform.forward * near + toTop - toRight;
			float scale = topLeft.magnitude / near;
			
			topLeft.Normalize();
			topLeft *= scale;
			
			Vector3 topRight = CameraTransform.forward * near + toRight + toTop;
			topRight.Normalize();
			topRight *= scale;
			
			Vector3 bottomLeft = CameraTransform.forward * near - toTop - toRight;
			bottomLeft.Normalize();
			bottomLeft *= scale;
			
			Vector3 bottomRight = CameraTransform.forward * near + toRight - toTop;
			bottomRight.Normalize();
			bottomRight *= scale;
			
			frustumCorners.SetRow(0, bottomLeft);
			frustumCorners.SetRow(1, bottomRight);
			frustumCorners.SetRow(2, topRight);
			frustumCorners.SetRow(3, topLeft);
			
			PubMat.SetMatrix("_FrustumCornersRay", frustumCorners);
			PubMat.SetVector("_WorldStructXYZ", WorldStructXYZ);
			PubMat.SetTexture("_NoiseTex", NoiseTex);

            PubMat.SetFloat("_FogDensity", fogDensity);
			PubMat.SetColor("_FogColor", fogColor);
			PubMat.SetFloat("_FogStart", fogStart);
			PubMat.SetFloat("_FogEnd", fogEnd);
			PubMat.SetFloat("_FogXSpeed", fogXSpeed);
			PubMat.SetFloat("_FogYSpeed", fogYSpeed);
			PubMat.SetFloat("_NoiseAmount", noiseAmount);
            Graphics.Blit(source,destination,PubMat);

            Debug.Log("sucess");
        }
        else
        {
            Graphics.Blit(source,destination);
            Debug.Log("Fail");
        }
    }
}
