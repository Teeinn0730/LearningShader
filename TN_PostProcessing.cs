using System;
using System.Collections;
using System.Collections.Generic;
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
    [Range(0,1)] public float Brightness = 1;
    [Range(1,10)] public int DownSample = 1;
    public int BlurIntensity = 5;
    public float blurSpread = 0.6f;
    [Range(0,1)] public float Threshold = 0.9f;
    [Range(0,5)] public int BloomLightIntensity = 1;

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        //OnRenderImage只能使用在Built_in管線當中，URP及HDRP請使用ScriptableRenderPass API。
        //OnRenderImage is not supported in the Scriptable Render Pipeline. To create custom fullscreen effects in the Universal Render Pipeline (URP), use the ScriptableRenderPass API. To create custom fullscreen effects in the High Definition Render Pipeline (HDRP), use a Fullscreen Custom Pass.
        //https://docs.unity3d.com/ScriptReference/Camera.OnRenderImage.html

        Bloom(ref source,ref destination);
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
    
}
