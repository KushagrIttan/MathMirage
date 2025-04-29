// SwagMLAPI.js
// Version: 0.0.4
// Event: On Awake
// Description: Main SwagML API

/**
* API
*
* Properties
*
* autoRun
*   @type bool
*   Enable/disable running the inference every frame
*
* forceSkipGenerator
*   @type bool
*   Enable/disable using the generator model
*
* targetImage
*   @type Texture
*   Image/video to which the garment will be applied
*
* garmentImage
*   @type Texture
*   The garment to apply, image of a person wearing a garment
*
* garmentMask
*   @type Texture
*   Use this texture as the source garment mask (segmentation) and skip source garment segmentation prediction.
*
* Functions
*
* isReady
*   @return bool
*   Returns true if all models are loaded and ready to execute
*
* shouldLive
*   @return bool
*   Returns the COF's json recommendation for live video or stills image
*
* run
*   Manually runs the inference once
*
* getResultStatus
*   @return {bool}
*   Returns the success status of the last inference
*/

// @input bool autoRun
// @input Asset.Texture targetImage
// @input Asset.Texture garmentImage
// @input Asset.Texture garmentMask = null

//@ui { "widget" : "separator" }
//@ui { "widget" : "separator" }
// @input bool debugTextures
// @input Component.ScriptComponent sourcePredictionScript
// @input Component.ScriptComponent drivingPredictionScript
// @input Component.ScriptComponent modelBuilder
// @input Asset.Texture outputTexture
// @input SceneObject genOutput
// @input Component.Camera outputCam
// @input SceneObject catTracker
// @input Asset.Material genOutputShader
// @input bool useGridSampleShader
// @input bool forceSkipGenerator = false
// @input bool forceDt = false
// @ui {"widget":"group_start", "label":"Skip Generator Inputs"}
// @input Asset.Material noGenOutputShader
//@ui {"widget":"group_end"}

//@input bool showTimings
//@input Component.Text sourceTimingsText { "showIf": "showTimings" }
//@input Component.Text drivingTimingsText { "showIf": "showTimings" }
//@input Asset.Texture drivingTexture
//@input Component.MLComponent[] windowsCpuMLComps
//@input Component.MLComponent[] cpuMLComps
//@input Component.MLComponent[] androidCpuMLComps
//@input Component.MLComponent warpingPostProcessOne
//@input Component.MLComponent warpingPostProcessMulti


var allModelsReady = false;
var lastGen = { success: false };
var sourceTex = null;
var sourceDirty = false;
var drivingTexture = script.drivingTexture;
// For realtime
var outputShader = null;
var options;

script.initMLComponentsAlreadyCalled = false;
script.genOutput.enabled = false;

const eventModule = require("./EventModule_101");
script.onLoadingFinished = new eventModule.EventWrapper();


// Use grid sample shader (1 - yes, 0 - no)
script.genOutputShader.mainPass.useShaderGridSample = script.useGridSampleShader;


var updateEvent = script.createEvent("UpdateEvent");
updateEvent.bind(function() {
    if (script.autoRun) {
        script.run();
    }
});


function initMLComponents() {
    script.initMLComponentsAlreadyCalled = true;
     // var genMetadata = {isLive: true, skipGenerator: global.deviceInfoSystem.getOS() == global.OS.Android, catTracker: global.deviceInfoSystem.getOS() == global.OS.iOS};
   let genMetadata = script.sourcePredictionScript.genMLComp.model.getMetadata();
    if (!("isLive" in genMetadata)){
        throw "Error, could not find isLive in Generator's metadata"
    }
    if (!("skipGenerator" in genMetadata)){
        throw "Error, could not find skipGenerator in Generator's metadata"
    }
    if (!("catTracker" in genMetadata)){
        genMetadata["catTracker"] = false;
        print("could not find catTracker in Generator's metadata");
    }

    script.skipGenerator = (script.forceSkipGenerator || genMetadata["skipGenerator"]);
    script.catTracker.enabled = !script.skipGenerator && genMetadata["catTracker"] && !global.deviceInfoSystem.isEditor();

    // Windows LS: Fall to LibDnn for given models than known to not work
    if (global.deviceInfoSystem.isEditor() &&
        global.deviceInfoSystem.getOS() == global.OS.Windows) {
        for (const mlc in script.windowsCpuMLComps) {
            const model = script.windowsCpuMLComps[mlc];
            // MachineLearning.InferenceMode.Libdnn == 4
            // The enum is not exist on LS public so we use the value itself
            model.inferenceMode = 4;
        }
    }
    // Run cpuMLComp with LibDnn (used for debugging)
    for (const mlc in script.cpuMLComps) {
        const model = script.cpuMLComps[mlc];
        // MachineLearning.InferenceMode.Libdnn == 4
        // The enum is not exist on LS public so we use the value itself
        model.inferenceMode = 4;
    }

    // Force androids ML components with LibDnn
    if (global.deviceInfoSystem.getOS() == global.OS.Android) {
        for (const mlc in script.androidCpuMLComps) {
            const model = script.androidCpuMLComps[mlc];
            // MachineLearning.InferenceMode.Libdnn == 4
            // The enum is not exist on LS public so we use the value itself
            model.inferenceMode = 4;
        }
    }


    // Realtime fallback
    options = {
        skipGenerator: script.skipGenerator,
        forceDt: script.forceDt ? 0.03333 : null
    };

    if (script.skipGenerator) {
        // Disable gen and postprocess models
        script.sourcePredictionScript.genMLComp.enabled = false;
        script.sourcePredictionScript.warpPostProcessMLComp.enabled = false;
    }

    // ios, mlindex<=3: Do not do anything
    if (global.deviceInfoSystem.getOS() == global.OS.iOS &&
        global.deviceInfoSystem.performanceIndexes.ml <= 3) {
        return;
    }

    // Set the output material (gen / no-gen)
    outputShader = script.skipGenerator?script.noGenOutputShader:script.genOutputShader;
    const outputImgComp = script.genOutput.getComponent("Component.Image");
    outputImgComp.clearMaterials();
    outputImgComp.addMaterial(outputShader);

    // Init models
    script.modelBuilder.buildModel(script.sourcePredictionScript.dpMLComp, ["driving_image"], [true]);
    script.modelBuilder.buildModel(script.sourcePredictionScript.warpMLComp, ["driving_image"], [true], ["bbox_mask"], false);

    if (!script.skipGenerator) {
        script.modelBuilder.buildModel(script.sourcePredictionScript.warpPostProcessMLComp, ["source_image", "source_mask"], [true, true]);
        script.modelBuilder.buildModel(script.drivingPredictionScript.genMLComponent,
                                        ["driving_image",
                                         "driving_mask_ug",
                                         "driving_mask_hair",
                                         "source_mask_ug",
                                         "source_mask"],
                                         [true, true, true, true, true],
                                         ["pred", "shader_masks"])
    }
    script.modelBuilder.buildModel(script.sourcePredictionScript.segMLComp, ["image"], [false], ["mask_hair", "mask_ug"]);
    script.modelBuilder.buildModel(script.drivingPredictionScript.segMLComp, ["image"], [false], ["mask_hair", "mask_ug"]);
    script.modelBuilder.buildModel(script.sourcePredictionScript.segBoxMLComp, ["mask"], [false], [], false);
    script.modelBuilder.buildModel(script.drivingPredictionScript.segBoxMLComp, ["mask"], [false], [], false);

    // connect texture output
    script.sourcePredictionScript.sourceSegTexture = script.sourcePredictionScript.segMLComp.getOutput("mask_ug").texture
    script.sourcePredictionScript.segBoxMLComp.getInput("mask").texture = script.sourcePredictionScript.segMLComp.getOutput("mask_ug").texture;
    script.drivingPredictionScript.segBoxMLComp.getInput("mask").texture = script.drivingPredictionScript.segMLComp.getOutput("mask_ug").texture;

    script.sourcePredictionScript.api.init(options);
    script.drivingPredictionScript.api.init(options);

    // Wait for all models to load
    script.modelBuilder.onLoadingFinished = function() {
        linkDataLayouts();
        allModelsReady = true;
        script.onLoadingFinished.trigger();
    };
}

script.createEvent("OnStartEvent").bind(initMLComponents);


script.isReady = function() {
    return allModelsReady;
};

script.shouldLive = function() {
   let genMetadata = script.sourcePredictionScript.genMLComp.model.getMetadata();
     // var genMetadata = {isLive: true};

   return genMetadata["isLive"];
};

script.setEnabled = function(en) {
    updateEvent.enabled = en;
};

function setSource(texture) {
    if (!texture) {
        return false;
    }

    sourceTex = texture;
    sourceDirty = true;
    return true;
}

function getSource() {
    return sourceTex;
}

function setDriving(texture) {
    if (!texture) {
        return false;
    }

    drivingTexture = texture;

    // set this texture as clear texture in output RT (needed when output is not ready)
    script.outputTexture.control.clearColorEnabled = true;
    script.outputTexture.control.clearColorOption = global.ClearColorOption.CustomTexture;
    script.outputTexture.control.inputTexture = drivingTexture;

    return true;
}

function getDriving() {
    return drivingTexture;
}

script.refreshSource = function() {
    sourceDirty = true;
};

script.run = function() {
    if (!script.isReady()) {
        lastGen.success = false;
        return false;
    }

    if (!sourceTex || !script.targetImage || !script.garmentImage) {
        lastGen.success = false;
        script.genOutput.enabled = false;
        return false;
    }

    if (sourceDirty) {
        var srcPredOptions = {
            customGarmentSeg: script.garmentMask
        };
        const result = script.sourcePredictionScript.api.run(sourceTex, srcPredOptions, script.debugTextures);
        if (result.success) {
            if (script.showTimings && script.sourceTimingsText && result.times) {
                script.sourceTimingsText.text = result.times;
            }
            sourceDirty = false;
            updateShaderSourceParams(result);
        }
    }

    lastGen = script.drivingPredictionScript.api.run(drivingTexture, script.debugTextures);
    if (lastGen.success) {
        if (script.showTimings && script.drivingTimingsText && lastGen.times) {
            script.drivingTimingsText.text = lastGen.times;
        }

        // pass gen results to output shader
        updateOutputShader(lastGen);
    }

    script.genOutput.enabled = lastGen.success;
    return lastGen.success;
};

function updateOutputShader(params) {
    const cropCenter = params.center.scale(new vec2(0.5, 0.5)).add(new vec2(0.5, 0.5));
    const cropSize = params.size.uniformScale(0.5);

    outputShader.mainPass.camTex = params.originalTex;
    outputShader.mainPass.cropCenter = cropCenter;
    outputShader.mainPass.cropSize = cropSize;

    outputShader.mainPass.flowRelative = params.flowRelative;
    outputShader.mainPass.flowHalfPx = 1.0 / (params.flowRelative.getWidth() * 2 / 5); // Div 5 because flowRelative is actually 5 images
    outputShader.mainPass.flowSelection = params.flowSelection;

    // Hair
    outputShader.mainPass.drivingHairMask = params.drivingHairMask;
    outputShader.mainPass.segRatioX = params.hairSegShiftScale.xRatio;
    outputShader.mainPass.segRatioY = params.hairSegShiftScale.yRatio;
    outputShader.mainPass.segShiftX = params.hairSegShiftScale.xShift;
    outputShader.mainPass.segShiftY = params.hairSegShiftScale.yShift;
    outputShader.mainPass.segPxSize = 1.0 / (params.flowRelative.getWidth() * 1);

    outputShader.mainPass.drivingGarmentMask = params.drivingGarmentMask;
    if (!params.skipGenerator) {
        // Material with generator
        outputShader.mainPass.genHalfPx = 1.0 / (params.generatedTex.getWidth() * 2);
        outputShader.mainPass.genTex = params.generatedTex;
        outputShader.mainPass.shaderMasksTex = params.shaderMasks;
        outputShader.mainPass.shaderMaskHalfPx = 1.0 / (params.shaderMasks.getWidth() * 2)
    } else {
        // Material without generator
        outputShader.mainPass.sourceParts = params.sourceParts;
    }
}

function updateShaderSourceParams(params) {
    const gridSampleParams = params.gridSampleParams;
    outputShader.mainPass.sourceCropTex = sourceTex;
    outputShader.mainPass.sourceGarmentMask = gridSampleParams.sourceGarmentMask;

    const w_wp = gridSampleParams.w_with_pad / gridSampleParams.w_without_pad;
    outputShader.mainPass.sx = gridSampleParams.cropBox.w * w_wp;
    outputShader.mainPass.dx = gridSampleParams.cropBox.x * w_wp;

    const h_hp = gridSampleParams.h_with_pad / gridSampleParams.h_without_pad;
    outputShader.mainPass.sy = gridSampleParams.cropBox.h * h_hp;
    outputShader.mainPass.dy = -gridSampleParams.cropBox.y * h_hp;
}

function linkDataLayouts() {
    linkDataLayout = script.modelBuilder.linkDataLayout;

    linkDataLayout(script.sourcePredictionScript.dpMLComp, "drv_emb", script.drivingPredictionScript.warpMLComp, "src_emb");
    linkDataLayout(script.drivingPredictionScript.warpMLComp, "drv_emb", script.drivingPredictionScript.warpMLComp, "prev_drv_emb");

    linkDataLayout(script.drivingPredictionScript.segMLComp, "mask_ug", script.drivingPredictionScript.segMLComp, "prev_ug_mask");
    linkDataLayout(script.drivingPredictionScript.segMLComp, "mask_hair", script.drivingPredictionScript.segMLComp, "prev_hair_mask");
    linkDataLayout(script.drivingPredictionScript.segMLComp, "mask_ug", script.drivingPredictionScript.segBoxMLComp, "mask");

    if (!script.skipGenerator){
      linkDataLayout(script.drivingPredictionScript.warpMLComp, "swapnet_uv_emb", script.drivingPredictionScript.warpPostProcessMLComp);

      linkDataLayout(script.drivingPredictionScript.warpMLComp, "deform_confidence", script.drivingPredictionScript.warpPostProcessMLComp);

      linkDataLayout(script.drivingPredictionScript.warpMLComp, "source_parts_01", script.drivingPredictionScript.warpPostProcessMLComp);
      linkDataLayout(script.drivingPredictionScript.warpMLComp, "source_parts_23", script.drivingPredictionScript.warpPostProcessMLComp);
      linkDataLayout(script.drivingPredictionScript.warpMLComp, "source_parts_45", script.drivingPredictionScript.warpPostProcessMLComp);
      linkDataLayout(script.sourcePredictionScript.dpMLComp, "driving_body_seg", script.drivingPredictionScript.warpPostProcessMLComp, "source_body_seg");


      linkDataLayout(script.drivingPredictionScript.warpMLComp, "driving_body_seg", script.drivingPredictionScript.genMLComponent);
      linkDataLayout(script.drivingPredictionScript.warpPostProcessMLComp, "selection_mask", script.drivingPredictionScript.genMLComponent);
      linkDataLayout(script.drivingPredictionScript.warpPostProcessMLComp, "deformed_source", script.drivingPredictionScript.genMLComponent);
      linkDataLayout(script.drivingPredictionScript.warpPostProcessMLComp, "deformed_source_mask", script.drivingPredictionScript.genMLComponent);
      linkDataLayout(script.drivingPredictionScript.warpPostProcessMLComp, "deformed_source_body_seg", script.drivingPredictionScript.genMLComponent);
      linkDataLayout(script.drivingPredictionScript.warpPostProcessMLComp, "swapnet_inputs", script.drivingPredictionScript.genMLComponent);
      linkDataLayout(script.drivingPredictionScript.warpMLComp, "confident_regions", script.drivingPredictionScript.genMLComponent);
    }
}

script.getResultStatus = function() {
    return lastGen.success;
};

Object.defineProperty(script, "garmentImage", {
    get: function() {
        return getSource();
    },
    set: function(tex) {
        setSource(tex);
    }
});

Object.defineProperty(script, "targetImage", {
    get: function() {
        return getDriving();
    },
    set: function(tex) {
        setDriving(tex);
    }
});
