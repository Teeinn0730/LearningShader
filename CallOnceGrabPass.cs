using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CallOnceGrabPass : ScreenShot
{
    private void OnEnable()
    {
        Static_TakeScreenShot(Screen.width,Screen.height);
    }
}
