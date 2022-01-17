using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Security;
using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class TN_PostEffectBase : MonoBehaviour
{
    protected void CheckResource()
    {
        bool isSupported = CheckSupport();
        if(isSupported == false)
            NotSupported();
    }

    protected bool CheckSupport()
    {
        if (SystemInfo.supportsImageEffects == false || SystemInfo.supportsRenderTextures == false)
        {
            Debug.LogWarning("This Platform is not support ImageEffect or RenderTexture.");
            return false;
        }
        return true;
    }

    protected void NotSupported()
    {
        enabled = false;
    }
    protected void Start()
    {
        CheckResource();
    }
    
    protected Material CheckShaderAndMat(Shader shader,Material Mat)
    {
        if(shader == null )
            return null;
        if(Mat == null)
            return new Material(shader);
        if(Mat || Mat.shader == shader)
            return Mat;
        else
        {
            Mat = new Material(shader);
            if(Mat)
                return Mat;
            else    
                return null;
        }

    }

}
