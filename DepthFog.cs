using System;
using System.Runtime.CompilerServices;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Rendering.Universal;
using static UnityEditor.ShaderData;
using FloatParameter = UnityEngine.Rendering.PostProcessing.FloatParameter;
using IntParameter = UnityEngine.Rendering.PostProcessing.IntParameter;
using PostProcessAttribute = UnityEngine.Rendering.PostProcessing.PostProcessAttribute;

[Serializable]
[PostProcess(typeof(DepthFogRenderer), PostProcessEvent.AfterStack, "Custom/DepthFog")]
public sealed class DepthFog : PostProcessEffectSettings
{
    [Range(0f, 1f), Tooltip("DepthFog effect intensity.")]
    public FloatParameter DepthSlider = new FloatParameter { value = 1f };
    [Range(0f, 1f), Tooltip("DepthFog effect intensity.")]
    public FloatParameter CameraToFog = new FloatParameter { value = 0f };
    [Range(1f, 10f), Tooltip("DepthFog effect intensity.")]
    public FloatParameter FogPower = new FloatParameter { value = 1f };
    [Range(1, 10), Tooltip("High Value will be more efficient , Otherwise low value would be more performance.")]
    public IntParameter DownSample = new IntParameter { value = 1 };
}
public sealed class DepthFogRenderer : PostProcessEffectRenderer<DepthFog>
{
    int mipDown;
    Camera maincamera;
    public override void Init()
    {
        mipDown = Shader.PropertyToID("_mipTex");
        maincamera = Camera.main;
    }

    public override void Render(PostProcessRenderContext context)
    {
        var cmd = context.command;
        cmd.BeginSample("DepthFog");

        int Width = Mathf.FloorToInt(context.screenWidth / settings.DownSample);
        int Height = Mathf.FloorToInt(context.screenHeight / settings.DownSample);

        var sheet = context.propertySheets.Get(Shader.Find("Unlit/DepthFog"));
        sheet.properties.SetFloat("_DepthSlider", settings.DepthSlider*maincamera.farClipPlane);
        sheet.properties.SetFloat("_CameraToFog", settings.CameraToFog*maincamera.farClipPlane);
        sheet.properties.SetFloat("_FogPower", settings.FogPower);
        #if UNITY_EDITOR
        Shader.SetGlobalMatrix("_InverseView",SceneView.currentDrawingSceneView.camera.cameraToWorldMatrix);
        #else
        Shader.SetGlobalMatrix("_InverseView",maincamera.cameraToWorldMatrix);
        #endif
        context.GetScreenSpaceTemporaryRT(cmd, mipDown, 0, context.sourceFormat, RenderTextureReadWrite.Default, FilterMode.Bilinear, Width, Height);
        cmd.BlitFullscreenTriangle(context.source, mipDown); //必須先把原尺寸的圖Blit進mipDown，才能在下一次的Blit中拿到小尺寸的mipDown。
        cmd.SetGlobalTexture("DepthFogTex", mipDown); //再透過SetGlobalTexture的方式把貼圖設回去。
        cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, 0); //等貼圖設成全局後，就可以跑一次完整的Blit環節(使用shader)。
        cmd.ReleaseTemporaryRT(mipDown);
        cmd.EndSample("DepthFog");

    }
}