using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class ScreenShot : MonoBehaviour
{
    private static ScreenShot instance;
    private bool takeScreenOnNextShot ;

    private void Awake()
    {
        instance = this ;
    }
    //private void OnPostRender()
    //{
    //    if (takeScreenOnNextShot)
    //    {
    //        takeScreenOnNextShot = false;
    //        RenderTexture renderTexture = Camera.main.targetTexture;
    //        Texture2D renderResult = new Texture2D(renderTexture.width,renderTexture.height,TextureFormat.RGBA32,false);
    //        Shader.SetGlobalTexture("_GrabOnce",renderResult);
    //        RenderTexture.ReleaseTemporary(renderTexture);
    //        Camera.main.targetTexture = null;
    //        Debug.Log("2s");
    //    }
    //}
    private void Update()
    {
        StartCoroutine(TakeScreenShot2());
    }
    
    private IEnumerator TakeScreenShot2()
    {
         if (takeScreenOnNextShot)
        {
            takeScreenOnNextShot = false;
            RenderTexture renderTexture = Camera.main.targetTexture;
            Camera.main.Render();
            Texture2D renderResult = new Texture2D(renderTexture.width, renderTexture.height, TextureFormat.ARGB32, false);
            Graphics.CopyTexture(renderTexture, renderResult); //Note: If you just want to copy the pixels from one texture to another and do not need to manipulate the pixel data on the CPU, it is faster to perform a GPU-to-GPU copy of the pixel data with Graphics.CopyTexture, CommandBuffer.CopyTexture, or Graphics.Blit. https://docs.unity3d.com/ScriptReference/Texture2D.ReadPixels.html
            Shader.SetGlobalTexture("_GrabOnce", renderResult);
            RenderTexture.ReleaseTemporary(renderTexture);
            Camera.main.targetTexture = null;
            Debug.Log("2s");
        }
         yield return new WaitForEndOfFrame();
    }
    private void TakeScreenShot(int width , int height)
    {
        Camera.main.targetTexture = RenderTexture.GetTemporary(width,height,16);
        takeScreenOnNextShot = true;
    }
    public static void Static_TakeScreenShot(int width , int height)
    {
        instance.TakeScreenShot(width,height);
    }
}
