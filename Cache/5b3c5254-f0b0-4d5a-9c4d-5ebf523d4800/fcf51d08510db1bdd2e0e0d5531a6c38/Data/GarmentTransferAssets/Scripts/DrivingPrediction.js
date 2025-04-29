// @input Component.MLComponent segMLComp
// @input Component.MLComponent segBoxMLComp
// @input Component.MLComponent warpMLComp
// @input Component.MLComponent warpPostProcessMLComp
// @input Component.MLComponent genMLComponent
// @input Asset.Texture cropTexture;
// @input Asset.Texture segCropTexture;
// @input Asset.Texture hairSegCropTexture;
// @input Component.ScriptComponent bboxScript
// @ui {"widget":"group_start", "label":"Debug Images"}
// @input Component.Image debugDrivingImage
// @input Component.Image debugDrivingSegImage
// @input Component.Image debugDrivingCropImage
// @input Component.Image debugDrivingSegCropImage
// @input Component.Image debugBboxMaskImage
// @input Component.Image debugWarpFlowImage
// @input Component.Image debugBodySegImage
// @input Component.Image debugGenImage
// @input Component.Image debugGenMaskImage
// @input Component.Image debugSmoothFactorImage
// @ui {"widget":"group_end"}
// @input bool verboseTiming
//@input Component.Camera gyroCam;


var personHighScoreThresh = 50;
var personLowScoreThresh = 5;

// Drive Prediction state
var cropInfo = null;
var personInView = false;
var USE_BUV_BBOX = true;
var BUV_BBOX_FALLBACK_IS_SEGBOX = true;
// fixCropbox set true only when sefie-training model is deployed
// current default mode is false
var fixCropbox = false;
if (script.verboseTiming) {
    var addTiming = global.utils.addTiming;
} else {
    var addTiming = function(key) {};
}
var settings = {};

function resetPreviousState(eventData) {
    if (cropInfo != null) {
        cropInfo.time = Number.MIN_SAFE_INTEGER;
    }
    script.warpMLComp.prev_time = Number.MIN_SAFE_INTEGER;

    // Flush previous masks inputs for the segmentation model
    var prevUGMask = script.segMLComp.getInput("prev_ug_mask").data;
    var prevHairMask = script.segMLComp.getInput("prev_hair_mask").data;
    TensorMath.mulScalar(prevUGMask, 0, prevUGMask);
    TensorMath.mulScalar(prevHairMask, 0, prevHairMask);
}

function adjustSegCropRect(texture, cropRect) {
    // segmentation model has padding to 2:1 ratio, so here we map the texture cropBox to the crop-box of
    // the 2:1 output-texture of the segmentation
    var w = texture.getWidth();
    var h = texture.getHeight();
    var x_pad = Math.max(0, h - 2 * w);
    var y_pad = Math.max(0, 2 * w - h);
    var w_with_pad = w + x_pad;
    var h_with_pad = h + y_pad;

    const newRect = Rect.create(cropRect.left * w / w_with_pad, cropRect.right * w / w_with_pad,
        cropRect.bottom * h / h_with_pad, cropRect.top * h / h_with_pad);
    return newRect;
}

function hairShiftScaleParams (drivingTexture){
    // Hair segmentation ratio/shift pass to material to align to image
    var w = drivingTexture.getWidth();
    var h = drivingTexture.getHeight();
    var hairSegShiftScale = {
        'xRatio' : Math.min(1, 2 * w / h),
        'yRatio' : Math.min(1, h / w / 2)
    };
    hairSegShiftScale['xShift'] = (1 - hairSegShiftScale['xRatio']) / 2;
    hairSegShiftScale['yShift'] = (1 - hairSegShiftScale['yRatio']) / 2;
    return hairSegShiftScale;
}

// Smoothing Params and Initialization
let smoothingParams = {
    'use_smoothing': true,
    'use_dynamic_smooth': true,

    // Opflow smoothing
    'smoothing_min': 0.3,
    'smoothing_max': 0.9,
    'opflow_input_size': new vec3(385, 385, 1),
    'opflow_window_size': new vec2(15, 15),
    'opflow_max_level': 2,
    'opflow_max_count': 10,
    'opflow_epsilon': 0.03,
    'opflow_smooth_multiplier': 4e4,

    // Gyro smoothing
    // smooth_factor = 0.5 * b * e^(-dt * c)
    'gyro_smooth_b': Math.exp(16.0 / 7.0),
    'gyro_smooth_c': 240.0 / 7.0,
    'fixed_bbox_smooth_max': 0.5,
    'unfixed_bbox_smooth_max': 0.3,
    'gyro_rotation_smooth_max': 0.0,
    'gyro_threshold': 0.006
}

let diffGyro = 0;

script.prevGyro = {'x': 0, 'y': 0, 'z': 0};
script.currGyro = {'x': 0, 'y': 0, 'z': 0};
if (global.deviceInfoSystem.getOS() == global.OS.iOS) {
    script.createEvent('LateUpdateEvent').bind(function () {
        script.prevGyro = script.currGyro;
        script.currGyro = script.gyroCam.getTransform().getWorldRotation();
    })
}


function updateParamsWithMetadata(params, metadata) {
    if (metadata != null) {
        for (let key in metadata) {
            if (key in params && params[key] instanceof vec2) {
                params[key].x = metadata[key][0];
                params[key].y = metadata[key][1];
            }
            else if (key in params && params[key] instanceof vec3) {
                params[key].x = metadata[key][0];
                params[key].y = metadata[key][1];

                if (metadata[key].length > 2) {
                    params[key].z = metadata[key][2];
                }
            }
            else {
                params[key] = metadata[key];
            }
        }
    }

    return params;
}

function initParams(opts) {
    // Overriding smoothing default params if provided in models
    let warpMetadata = script.warpMLComp.model.getMetadata();
    let smooth_factor_shape = script.warpMLComp.getInput('smooth_factor').shape;
    smoothingParams['opflow_grid_size'] = new vec2(smooth_factor_shape.x, smooth_factor_shape.y);

    if (warpMetadata != null && 'smoothing_params' in warpMetadata) {
        smoothingParams = updateParamsWithMetadata(smoothingParams, warpMetadata['smoothing_params']);
    }

    return opts
}

// ========================
// Optical Flow Smoothing

function createCoordGrid(gridSize, outputScale) {
    let grid = new Float32Array(gridSize.x * gridSize.y * 2);

    for (let x = 0; x < gridSize.x; x++) {
        for (let y = 0; y < gridSize.y; y++) {
            let ix = (y * gridSize.x + x) * 2 + 0;
            let iy = (y * gridSize.x + x) * 2 + 1;
            grid[ix] = (x + 0.5) / gridSize.x * outputScale.x;
            grid[iy] = (1. - (y + 0.5) / gridSize.y) * outputScale.y;
        }
    }

    return grid;
}

function initOpticalFlowSmoothing() {
    script.opflowPrevFrame = new Uint8Array(
        smoothingParams.opflow_input_size.x *
        smoothingParams.opflow_input_size.y *
        smoothingParams.opflow_input_size.z
    );
    script.opflowCurrFrame = new Uint8Array(script.opflowPrevFrame.length);

    script.opflowGrid = createCoordGrid(smoothingParams.opflow_grid_size, smoothingParams.opflow_input_size);
    script.opflowResult = new Float32Array(script.opflowGrid.length);

    script.warpMLComp.smooth_factor = new Float32Array(smoothingParams.opflow_grid_size.x * smoothingParams.opflow_grid_size.y);
    script.warpMLComp.prev_time = Number.MIN_SAFE_INTEGER;
}

function calcOpticalFlowSmoothing(currFrameTexture, outputArray) {
    // Convert texture to grayscale and run optical flow
    TensorMath.textureToGrayscale(currFrameTexture, script.opflowCurrFrame, smoothingParams.opflow_input_size);

    script.opflowResult.set(script.opflowGrid);
    TensorMath.opticalFlow(
        script.opflowPrevFrame, script.opflowCurrFrame, smoothingParams.opflow_input_size,
        script.opflowResult, script.opflowResult,
        new vec3(2, smoothingParams.opflow_grid_size.x * smoothingParams.opflow_grid_size.y, 1),
        smoothingParams.opflow_window_size, smoothingParams.opflow_max_level,
        smoothingParams.opflow_max_count, smoothingParams.opflow_epsilon
    );

    script.opflowPrevFrame.set(script.opflowCurrFrame);

    // Calc smoothing factor
    // `1 /  (c * ||I' - I||^2 + 1)`
    // where I' is the optical flow result for I and I is the identity grid
    // c is `opflow_smooth_multiplier` normalized by the input size
    let resultShape = new vec3(2, smoothingParams.opflow_grid_size.y, smoothingParams.opflow_grid_size.x);
    TensorMath.subTensors(
        script.opflowResult, resultShape,
        script.opflowGrid, resultShape,
        script.opflowResult
    );
    TensorMath.power(script.opflowResult, 2, script.opflowResult);
    TensorMath.sum(script.opflowResult, resultShape, new vec3(0, 1, 1), outputArray);
    TensorMath.mulScalar(
        outputArray,
        smoothingParams.opflow_smooth_multiplier /
        smoothingParams.opflow_input_size.x /
        smoothingParams.opflow_input_size.y,
        outputArray
    );
    TensorMath.addScalar(outputArray, 1., outputArray);
    TensorMath.power(outputArray, -1., outputArray);

    return outputArray;
}

// ========================

function runSegMLComp(texture, sync) {
    // Predict Segmenttaion Mask
    script.segMLComp.getInput("image").texture = texture;
    script.segMLComp.runImmediate(sync);

    // Save current mask outputs as the next "previous" masks
    script.segMLComp.getInput("prev_ug_mask").data.set(script.segMLComp.getOutput("mask_ug").data);
    script.segMLComp.getInput("prev_hair_mask").data.set(script.segMLComp.getOutput("mask_hair").data);
}

function runSegBoxMLComp(sync) {
    // Get the segmentation box
    script.segBoxMLComp.getInput("mask").data.set(script.segMLComp.getOutput("mask_ug").data);
    script.segBoxMLComp.runImmediate(sync);
}


function cropFrames(drivingTexture) {
    // shared state with BboxCalculator.js
    script.bboxScript.shareState({
        drivingTexture: drivingTexture,
        upperGarmentMaskTexture: script.segMLComp.getOutput("mask_ug").texture,
        fixCropbox: fixCropbox,
        warpMLComp: script.warpMLComp,
        segBoxMLComp: script.segBoxMLComp
    });

    // check if need to run buvBbox() or segmentationBbox()
    var bbox;
    if (USE_BUV_BBOX) {
        bbox = script.bboxScript.buvBbox(cropInfo);
        if (bbox.fallback && BUV_BBOX_FALLBACK_IS_SEGBOX) {
            runSegBoxMLComp(true); // run the ML component
            bbox = script.bboxScript.segmentationBbox(cropInfo, true); // run segmentationBbox in fallback mode
        }
    } else {
        bbox = script.bboxScript.segmentationBbox(cropInfo, false);
    }


    const boxDims = script.bboxScript.calcCropBox(bbox);

    cropInfo = script.bboxScript.cropInfoPostProcess(cropInfo, bbox, boxDims, USE_BUV_BBOX);

    var cropRect = Rect.create(boxDims.crop_left, boxDims.crop_right, boxDims.crop_bottom, boxDims.crop_top);
    var segCropRect = adjustSegCropRect(drivingTexture, cropRect);
    script.cropTexture.control.cropRect = cropRect;
    script.segCropTexture.control.cropRect = segCropRect;
    script.hairSegCropTexture.control.cropRect = segCropRect;
    return cropInfo;
}

function diffFloats(a, b){
    // return Math.pow(a - b, 2);
    return Math.abs(a - b);
}

function calcBuvSmoothFactor(prevSmoothingFactor) {
    let smooth_factor = prevSmoothingFactor;

    // Calc dense smoothing using optical flow
    if (smoothingParams.use_smoothing) {
        smooth_factor = calcOpticalFlowSmoothing(script.cropTexture, smooth_factor);
    }

    // Determine the range of smoothing based on the gyro
    let time = getTime(); // in seconds.
    let dt = (settings.forceDt == null) ? time - script.warpMLComp.prev_time : settings.forceDt;

    let smoothing_min = smoothingParams.smoothing_min;
    let smoothing_max = smoothingParams.smoothing_max;

    script.warpMLComp.prev_time = time;
    if ((!smoothingParams.use_smoothing) || dt > 0.5 || dt <= 0) {
        smoothing_min = 0;
        smoothing_max = 0;
    }
    else if (smoothingParams.use_dynamic_smooth) {
        // Gyro
        if (global.deviceInfoSystem.getOS() == global.OS.iOS) {
            var diffX = diffFloats(script.currGyro.x, script.prevGyro.x);
            var diffY = diffFloats(script.currGyro.y, script.prevGyro.y);
            var diffZ = diffFloats(script.currGyro.z, script.prevGyro.z);
            diffGyro = diffX + diffY + diffZ;
        }

        // Calc smooth_fps_factor
        // wanted: 8fps --> alpha = e-2/2
        // wanted 15fps --> alpha = 1
        // smooth = b * e^(-dt * c)
        smooth_fps_factor = smoothingParams.gyro_smooth_b * Math.exp(-dt * smoothingParams.gyro_smooth_c);
        smooth_fps_factor = (smooth_fps_factor > 1) ? 1 : smooth_fps_factor;

        // If bbox is the same as previous frame
        if ((cropInfo.prevCropInfo != null) &&
            (cropInfo.x == cropInfo.prevCropInfo.x) &&
            (cropInfo.y == cropInfo.prevCropInfo.y) &&
            (cropInfo.box_size == cropInfo.prevCropInfo.box_size)) {
            smoothing_min = smoothingParams.fixed_bbox_smooth_max * smooth_fps_factor;
        } else {
            smoothing_min = smoothingParams.unfixed_bbox_smooth_max * smooth_fps_factor;
        }

        if (diffGyro > script.warpMLComp.gyro_threshold) {
            smoothing_min = smoothingParams.gyro_rotation_smooth_max * smooth_fps_factor;
        }
    }

    TensorMath.clamp(smooth_factor, smoothing_min, smoothing_max, smooth_factor);
    return smooth_factor;
}

function runWarpMLComp(sync) {
    script.warpMLComp.waitOnLoading();
    script.warpMLComp.getInput("smooth_factor").data.set(calcBuvSmoothFactor(script.warpMLComp.smooth_factor));
    script.warpMLComp.getInput("prev_drv_emb").data.set(script.warpMLComp.getOutput("drv_emb").data);
    script.warpMLComp.getInput("driving_image").texture = script.cropTexture;

    script.warpMLComp.runImmediate(sync);
    addTiming("warping");

    var personScore = script.warpMLComp.getOutput("driving_person_score").data[0];

    if (!settings.skipGenerator) {
        script.warpPostProcessMLComp.waitOnLoading();
        script.warpPostProcessMLComp.getInput("flow_relative_0").data.set(script.warpMLComp.getOutput("flow_relative_0").data);
        script.warpPostProcessMLComp.getInput("flow_relative_1").data.set(script.warpMLComp.getOutput("flow_relative_1").data);
        script.warpPostProcessMLComp.getInput("flow_relative_2").data.set(script.warpMLComp.getOutput("flow_relative_2").data);
        script.warpPostProcessMLComp.getInput("flow_relative_3").data.set(script.warpMLComp.getOutput("flow_relative_3").data);
        script.warpPostProcessMLComp.getInput("flow_relative_4").data.set(script.warpMLComp.getOutput("flow_relative_4").data);
        script.warpPostProcessMLComp.getInput("source_parts_01").data.set(script.warpMLComp.getOutput("source_parts_01").data);
        script.warpPostProcessMLComp.getInput("source_parts_23").data.set(script.warpMLComp.getOutput("source_parts_23").data);
        script.warpPostProcessMLComp.getInput("source_parts_45").data.set(script.warpMLComp.getOutput("source_parts_45").data);
        script.warpPostProcessMLComp.getInput("flow_selection_logits_01").data.set(script.warpMLComp.getOutput("flow_selection_logits_01").data);
        script.warpPostProcessMLComp.getInput("flow_selection_logits_23").data.set(script.warpMLComp.getOutput("flow_selection_logits_23").data);
        script.warpPostProcessMLComp.getInput("flow_selection_logits_45").data.set(script.warpMLComp.getOutput("flow_selection_logits_45").data);

        script.warpPostProcessMLComp.getInput("deform_confidence").data.set(script.warpMLComp.getOutput("deform_confidence").data);
        script.warpPostProcessMLComp.getInput("swapnet_uv_emb").data.set(script.warpMLComp.getOutput("swapnet_uv_emb").data);

        script.warpPostProcessMLComp.runImmediate(sync);
        addTiming("wrp_postprocess");
    }
    if (personScore > personHighScoreThresh) {
        personInView = true;
    } else if (personScore < personLowScoreThresh) {
        personInView = false;
    }
}

function runGenMLComp(sync) {
    // Generate
    script.genMLComponent.waitOnLoading();
    script.genMLComponent.getInput("driving_image").texture = script.cropTexture;
    script.genMLComponent.getInput("driving_mask_ug").texture = script.segCropTexture;
    script.genMLComponent.getInput("confident_regions").data.set(script.warpMLComp.getOutput("confident_regions").data);
    script.genMLComponent.getInput("driving_body_seg").data.set(script.warpMLComp.getOutput("driving_body_seg").data);
    script.genMLComponent.getInput("selection_mask").data.set(script.warpPostProcessMLComp.getOutput("selection_mask").data);
    script.genMLComponent.getInput("deformed_source").data.set(script.warpPostProcessMLComp.getOutput("deformed_source").data);
    script.genMLComponent.getInput("deformed_source_mask").data.set(script.warpPostProcessMLComp.getOutput("deformed_source_mask").data);
    script.genMLComponent.getInput("deformed_source_body_seg").data.set(script.warpPostProcessMLComp.getOutput("deformed_source_body_seg").data);
    script.genMLComponent.getInput("swapnet_inputs").data.set(script.warpPostProcessMLComp.getOutput("swapnet_inputs").data);

    script.genMLComponent.runImmediate(sync);
}

function getTimingsString(times) {
    return "Segmentation: " + (times.seg - times.start) + "ms\n"+
        "SegBox: " + (times.segbox - times.seg) + "ms\n"+
        "Crop: "+ (times.crop - times.segbox) + "ms\n"+
        "DensePose: "+ (times.dp - times.crop) + "ms\n"+
        "Warping: "+ (times.warp - times.dp) + "ms\n"+
        "Generator: "+ (times.gen - times.warp) + "ms\n"+
        "Total: "+(times.gen - times.start) + "ms";
}

function getTimingsJson(times) {
    return {
        segmentation: (times.seg - times.start),
        segbox: (times.segbox - times.seg),
        crop: (times.crop - times.segbox),
        densepose: (times.dp - times.crop),
        warping: (times.warp - times.dp),
        generator: (times.gen - times.warp),
        total: (times.gen - times.start)
    };
}

function setPixelsFloat32Concat(tex, placeHolders) {
    var sizeX = 0;
    for (var i=0; i<placeHolders.length; i++) {
        ph = placeHolders[i];
        tex.control.setPixelsFloat32(sizeX, 0, ph.shape.x, ph.shape.y, ph.data);
        sizeX += ph.shape.x;
    }
}

// run returns an object
// { originalTex: texture, generatedTex: texture, generatedMaskTex: texture, center: vec2, size: vec2 }
//
script.api.run = function(drivingTexture, debug) {
    script.segMLComp.onRunningFinished = function() {};
    script.segBoxMLComp.onRunningFinished = function() {};
    script.warpMLComp.onRunningFinished = function() {};
    script.genMLComponent.onRunningFinished = function() {};
    var tex;

    var times = {};
    times.start = new Date().getTime();
    addTiming("startDriving");

    if (debug) {
        script.debugDrivingImage.mainPass.baseTex = drivingTexture;
    }

    runSegMLComp(drivingTexture, true);
    times.seg = new Date().getTime();
    addTiming("drivingSeg");

    // only run segBoxMLComp when USE_BUV_BBOX is false
    if (!USE_BUV_BBOX) {
        runSegBoxMLComp(true);
    }
    times.segbox = new Date().getTime();

    script.cropTexture.control.inputTexture = drivingTexture;
    cropInfo = cropFrames(drivingTexture);
    times.crop = new Date().getTime();
    addTiming("crop");

    runWarpMLComp(true);
    times.warp = new Date().getTime();

    if (debug) {
        script.debugDrivingSegImage.mainPass.baseTex = script.segMLComp.getOutput("mask_ug").texture;
        script.debugDrivingSegImage.mainPass.tex2 = script.segMLComp.getOutput("mask_hair").texture;

        script.debugDrivingCropImage.mainPass.baseTex = script.cropTexture;

        script.debugDrivingSegCropImage.mainPass.tex1 = script.cropTexture;
        script.debugDrivingSegCropImage.mainPass.tex2 = script.segCropTexture;
        script.debugDrivingSegCropImage.mainPass.tex2_opacity = 0.5;

        var tex = global.utils.createTextureFromData(script.warpMLComp.getOutput("flow_relative_4").data, 33, 33, 2, -1, 1);
        script.debugWarpFlowImage.mainPass.baseTex = tex;
        tex = global.utils.createTextureFromData(script.warpMLComp.getOutput("driving_body_seg").data, 33, 33, 1, 0, 1, false, true);
        script.debugBodySegImage.mainPass.baseTex = tex;

        var tex = global.utils.createTextureFromData(script.warpMLComp.getOutput("bbox_mask").data, 33, 33, 1, 0, 255);
        script.debugBboxMaskImage.mainPass.baseTex = tex;

        script.debugSmoothFactorImage.mainPass.baseTex = global.utils.createTextureFromData(
            script.warpMLComp.getInput("smooth_factor").data,
            script.warpMLComp.getInput("smooth_factor").shape.x,
            script.warpMLComp.getInput("smooth_factor").shape.y,
            script.warpMLComp.getInput("smooth_factor").shape.z,
            0, 1
        );
   }

    var shift_x = 2 * (cropInfo.x + cropInfo.box_size / 2) / drivingTexture.getWidth() - 1;
    var shift_y = 2 * (cropInfo.y + cropInfo.box_size / 2) / drivingTexture.getHeight() - 1;
    var resize_x = 2 * cropInfo.box_size / drivingTexture.getWidth();
    var resize_y = 2 * cropInfo.box_size / drivingTexture.getHeight();

    const result = {};
    if (personInView) {
        if (!settings.skipGenerator) {
            runGenMLComp(true);
            addTiming("generator");

            if (debug) {
                script.debugGenImage.mainPass.baseTex = global.utils.createTextureFromData(
                    script.genMLComponent.getOutput("pred").data,
                    script.genMLComponent.getOutput("pred").shape.x,
                    script.genMLComponent.getOutput("pred").shape.y,
                    script.genMLComponent.getOutput("pred").shape.z,
                    0, 1, false, true
                );
                script.debugGenMaskImage.mainPass.baseTex = script.genMLComponent.getOutput("shader_masks").texture;
            }
        }
        times.gen = new Date().getTime();

        var timesString = getTimingsString(times);
        var timesJson = {};
        if (debug) {
            timesJson = getTimingsJson(times);
        }

        setPixelsFloat32Concat(script.flowRelative, [
            script.warpMLComp.getOutput("flow_relative_0"),
            script.warpMLComp.getOutput("flow_relative_1"),
            script.warpMLComp.getOutput("flow_relative_2"),
            script.warpMLComp.getOutput("flow_relative_3"),
            script.warpMLComp.getOutput("flow_relative_4")
        ])
        setPixelsFloat32Concat(script.flowSelection, [
            script.warpMLComp.getOutput("flow_selection_logits_01"),
            script.warpMLComp.getOutput("flow_selection_logits_23"),
            script.warpMLComp.getOutput("flow_selection_logits_45")
        ])

        if (settings.skipGenerator) {
            setPixelsFloat32Concat(script.sourceParts, [
                script.warpMLComp.getOutput("source_parts_01"),
                script.warpMLComp.getOutput("source_parts_23"),
                script.warpMLComp.getOutput("source_parts_45")
            ])
        }
        else {
            setPixelsFloat32Concat(script.genPred, [script.genMLComponent.getOutput("pred")])
        }

        result.success = true;
        result.skipGenerator = settings.skipGenerator;
        result.times = timesString;
        result.timesJson = timesJson;
        result.originalTex = drivingTexture;
        result.center = new vec2(shift_x, shift_y);
        result.size = new vec2(resize_x, resize_y);

        result.flowRelative = script.flowRelative;
        result.flowSelection = script.flowSelection;

        result.hairSegShiftScale = hairShiftScaleParams(drivingTexture);
        result.drivingHairMask = script.segMLComp.getOutput("mask_hair").texture;

        if (!settings.skipGenerator) {
            result.generatedTex = script.genPred;
            // shader_masks is cat([swap_mask, blend_mask_pre_avg, blend_mask_avg], dim=1)
            result.shaderMasks = script.genMLComponent.getOutput("shader_masks").texture;
        }
        else {
            result.sourceParts = script.sourceParts;
        }
    } else {
        // No person in view
        resetPreviousState();
        result.success = false;
    }

    return result;
};

script.api.init = function(opts) {
    settings = initParams(opts);

    script.createEvent("CameraBackEvent").bind(resetPreviousState);
    script.createEvent("CameraFrontEvent").bind(resetPreviousState);

    script.segCropTexture.control.inputTexture = script.segMLComp.getOutput("mask_ug").texture;
    script.hairSegCropTexture.control.inputTexture = script.segMLComp.getOutput("mask_hair").texture;

    script.bboxScript.setMaskBoundingBoxVars(script.warpMLComp.getOutput("bbox_mask").shape);
    script.bboxScript.setForceDt(settings.forceDt);

    initOpticalFlowSmoothing();

    // Create shader textures
    flowRelativeShape = script.warpMLComp.getOutput("flow_relative_0").shape
    const RGFloat = 5 // Public API doesn't have Colorspace.RGFloat
    script.flowRelative = ProceduralTextureProvider.create(flowRelativeShape.x*5, flowRelativeShape.y, RGFloat);
    script.flowSelection = ProceduralTextureProvider.create(flowRelativeShape.x*3, flowRelativeShape.y, RGFloat);

    if (settings.skipGenerator) {
        script.sourceParts = ProceduralTextureProvider.create(flowRelativeShape.x*3, flowRelativeShape.y, RGFloat);
    }
    else {
        const RGBAFloat = 6 // Public API doesn't have Colorspace.RGBAFloat
        let genShape = script.genMLComponent.getOutput("pred").shape;
        script.genPred = ProceduralTextureProvider.create(genShape.x, genShape.y, RGBAFloat);
    }

    return true;
};
