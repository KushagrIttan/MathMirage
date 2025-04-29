/**
* Garment Transfer Custom Component
*
* API
*
* Properties
*
* autoRun
*   @type bool
*   Enable/disable running the inference every frame
*
* runMode
*   @type int
*   0 - "Adapt to Device Performance" - Automatic choice according to device's performance
*   1 - "Optimize Speed" - Always use the lighter version of Garment Transfer
*
* targetImage
*   @type Texture
*   Image/video to which the garment will be applied
*
* garmentImage
*   @type Texture
*   The garment to apply, image of a person wearing a garment
*
* enabled
*   @type bool
*   Enable/Disable auto inference and shows/hides the result
*
* Functions
*
* run()
*   Manually runs the inference once
*
* refreshGarment()
*   Force garment image refresh
*   This method can be used when a refresh to the garment is desired without changing it.
*   Mainly useful when using a video as garmentImage
*
* isReady()
*   Returns boolean, true when the component is ready for generating results.
*
* garmentMask
*   @type Texture
*   Use this texture as the source garment mask (segmentation) and skip source garment segmentation prediction.
*
* Events
*
* onLoadingFinished
* Triggers when the component is ready to generate result isReady() is true.
*/

//@input bool autoRun { "hint" : "Automatically runs every frame" }
// @input int runMode {"widget": "combobox", "values": [{"label":"Adapt to Device Performance", "value": 0}, {"label":"Optimize Speed", "value": 1}]}

//@input Asset.Texture targetImage { "hint" : "Shirt would be applied to this image/video" }
//@input Asset.Texture garmentImage { "hint" : "Image of a person wearing a shirt" }

//@input Asset.ObjectPrefab gtPrefab
//@input Asset.Material outputMaterial
// @ui {"widget":"group_start", "label":"Advanced"}
// @input Asset.Texture garmentMask = null {"hint":"Use this source garment mask instead of predicting it"}
// @ui {"widget":"group_end"}

// Destruction Helper
var DestructionHelper = require("./DestructionHelper_100");
var manager = new DestructionHelper(script);

var gtApi = null;

const RunMode = {
	Auto: 0,
	Speed: 1,
}

function getObjectByName(obj, name) {
    if (!obj) {
        return null;
    }

    if (obj.name == name) {
        return obj;
    }

    for (var i=0; i<obj.getChildrenCount(); i++) {
        const c = getObjectByName(obj.getChild(i), name);
        if (c) {
            return c;
        }
    }

    return null;
}

function getParentCamera(obj) {
    if (!obj) {
        return null;
    }

    var cam = obj.getComponent("Component.Camera");
    if (cam) {
        return cam;
    }

    return getParentCamera(obj.getParent());
}

function init() {
    // Get main Garment Transfer script (SwagMLAPI)
    const rootSo = manager.createSceneObject(null);
    const gtSo = script.gtPrefab.instantiate(rootSo);
    const gtApiSo = getObjectByName(gtSo, "SwagMLAPI");
    if (!gtApiSo) {
        rootSo.destroy();
        print("Error in Garment Transfer: Could not find api scene object");
        return;
    }
    gtApi = gtApiSo.getComponent("Component.ScriptComponent");
    // pass api calls on this script to gtApi
    script.run = gtApi.run;
    // add api to force refresh of the garment image
    script.refreshGarment = function() {
        gtApi.refreshSource();
    };
    gtApi.forceSkipGenerator = (script.runMode == RunMode.Speed);


    // Create Image Component
    const selfSo = script.getSceneObject();
    const imageComp = manager.createComponent(selfSo, "Component.Image");
    imageComp.addMaterial(script.outputMaterial);
    imageComp.mainMaterial.mainPass.baseTex = gtApi.outputTexture;
    imageComp.mainMaterial.mainPass.baseColor = new vec4(1,1,1,1);

    // Adjust render orders
    // Render order in scene should be as follows: GT output cam -> parent cam
    // This could be removed if we run the models onRender
    const parentCam = getParentCamera(selfSo);
    if (!parentCam) {
        rootSo.destroy();
        imageComp.destroy();
        print("Error in Garment Transfer: Please create the component under a camera");
        return;
    }

    const outputCamObj = getObjectByName(gtSo, "OutputCam");
    const outputCam = outputCamObj.getComponent("Component.Camera");
    outputCam.renderOrder = parentCam.renderOrder-1;

    // Set unique layers for output camera and image
    const outputImgObj = getObjectByName(outputCamObj, "Output Image");
    const outputLayer = LayerSet.makeUnique();
    outputCam.renderLayer = outputLayer;
    outputImgObj.layer = outputLayer;

    // Set garment and base textures
    gtApi.autoRun = script.autoRun;
    gtApi.targetImage = script.targetImage;
    gtApi.garmentMask = script.garmentMask;
    gtApi.garmentImage = script.garmentImage;

    // Set function for flags recommendation
    script.shouldLive = gtApi.shouldLive;
    script.isReady = gtApi.isReady;
    script.onLoadingFinished = gtApi.onLoadingFinished;

    script.createEvent("OnEnableEvent").bind(function() {
        if (gtApi) {
            gtApi.setEnabled(true);
        }
        if (imageComp) {
            imageComp.enabled = true;
        }
    });
    script.createEvent("OnDisableEvent").bind(function() {
        if (gtApi) {
            gtApi.setEnabled(false);
        }
        if (imageComp) {
            imageComp.enabled = false;
        }
    });
}

init();

Object.defineProperty(script, "autoRun", {
    get: function() {
        if (!gtApi) {
            print("error: could not get autoRun");
            return null;
        }
        return gtApi.autoRun;
    },
    set: function(auto) {
        if (!gtApi) {
            print("error: could not set autoRun");
            return;
        }
        gtApi.autoRun = auto;
    }
});

Object.defineProperty(script, "runMode", {
    get: function() {
        if (!gtApi) {
            print("error: could not get runMode");
            return null;
        }
        return gtApi.runMode;
    },
    set: function(runMode) {
        if (!gtApi) {
            print("error: could not set runMode");
            return;
        }
        if (!gtApi.initMLComponentsAlreadyCalled){
            gtApi.runMode = runMode;
            gtApi.forceSkipGenerator = (runMode == RunMode.Speed);
        }
        else{
            print("error: could not set runMode, init has already been called");
            return;
        }
    }
});

Object.defineProperty(script, "garmentImage", {
    get: function() {
        if (!gtApi) {
            print("error: could not get garmentImage");
            return null;
        }
        return gtApi.garmentImage;
    },
    set: function(tex) {
        if (!gtApi) {
            print("error: could not set garmentImage");
            return;
        }
        gtApi.garmentImage = tex;
    }
});

Object.defineProperty(script, "targetImage", {
    get: function() {
        if (!gtApi) {
            print("error: could not get targetImage");
            return null;
        }
        return gtApi.targetImage;
    },
    set: function(tex) {
        if (!gtApi) {
            print("error: could not set targetImage");
            return;
        }
        gtApi.targetImage = tex;
    }
});

Object.defineProperty(script, "garmentMask", {
    get: function() {
        if (!gtApi) {
            print("error: could not get garmentMask");
            return null;
        }
        return gtApi.garmentMask;
    },
    set: function(tex) {
        if (!gtApi) {
            print("error: could not set garmentMask");
            return;
        }
        gtApi.garmentMask = tex;
    }
});