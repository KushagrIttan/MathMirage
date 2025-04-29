// @input Component.MLComponent segMLComp
// @input Component.MLComponent segBoxMLComp
// @input Component.MLComponent dpMLComp
// @input Component.MLComponent warpMLComp
// @input Component.MLComponent warpPostProcessMLComp
// @input Component.MLComponent genMLComp
// @input Asset.Texture cropTexture;
// @input Asset.Texture cropSegTexture;
// @input Asset.Texture sourceSegTexture;
// @ui {"widget":"group_start", "label":"Debug Images"}
// @input Component.Image debugSourceImage
// @input Component.Image debugSourceSegImage
// @input Component.Image debugSourceCropImage
// @input Component.Image debugSourceSegCropImage
// @input Component.Image debugSourceDPImage
// @ui {"widget":"group_end"}

var gridSampleParams = null;
var settings = {};

var calcCropBox = function(box, origTexture) {
    var x = box[0];
    var y = box[1];
    var w = 6 * box[2];
    var h = 6 * box[3];

    // Make crop rect a square
    var orig_w = origTexture.control.getWidth();
    var orig_h = origTexture.control.getHeight();
    //    print("[calcCropBox] origSize: "+orig_w+"x"+orig_h);

    // move to pixel space
    w = w * orig_w;
    h = h * orig_h;
    var max_wh = Math.max(w, h);
    w = max_wh / orig_w;
    h = max_wh / orig_h;

    //    print("[calcCropBox] out box: "+x+"x"+y+" "+w+"x"+h)

    return {
        x: x,
        y: -y,
        w: w,
        h: h
    };
};

var updateCrop = function(provider, cropBox) {
    // Update cropping
    provider.cropRect = Rect.create(cropBox.x-0.5*cropBox.w, cropBox.x+0.5*cropBox.w,
        cropBox.y-0.5*cropBox.h, cropBox.y+0.5*cropBox.h);
};

function adjustCropBoxSegPadding(texture, cropBox) {
    // segmentation model has padding to 2:1 ratio, so here we map the texture cropBox to the crop-box of
    // the 2:1 output-texture of the segmentation
    var w = texture.getWidth();
    var h = texture.getHeight();
    var x_pad = Math.max(0, h - 2 * w);
    var y_pad = Math.max(0, 2 * w - h);
    var w_with_pad = w + x_pad;
    var h_with_pad = h + y_pad;

    var segCropBox = {x: cropBox.x * w / w_with_pad,
        y: cropBox.y * h / h_with_pad,
        h: cropBox.h * h / h_with_pad,
        w: cropBox.w * w / w_with_pad,
    };
    return segCropBox;
}

function runSegMLComp(texture, sync) {
    script.segMLComp.waitOnLoading();
    script.segMLComp.getInput("image").texture = texture;

    var prevUGMask = script.segMLComp.getInput("prev_ug_mask").data;
    var prevHairMask = script.segMLComp.getInput("prev_hair_mask").data;

    // Flush previous masks inputs for new source garment
    TensorMath.mulScalar(prevUGMask, 0, prevUGMask);
    TensorMath.mulScalar(prevHairMask, 0, prevHairMask);
    script.segMLComp.runImmediate(sync);

    prevUGMask.set(script.segMLComp.getOutput("mask_ug").data);
    prevHairMask.set(script.segMLComp.getOutput("mask_hair").data);
    script.segMLComp.runImmediate(sync);
}

function runSegBoxMLComp(sync) {
    script.segBoxMLComp.waitOnLoading();
    script.segBoxMLComp.runImmediate(sync);
}

function runDPMLComp(sync, customGarmentSeg) {

    var box = script.segBoxMLComp.getOutput("box").data;
    const cropBox = calcCropBox(box, script.cropTexture.control.inputTexture);

    gridSampleParams.cropBox = {
        "x" : cropBox.x,
        "y" : cropBox.y,
        "w" : cropBox.w / 2,
        "h" : cropBox.h / 2,
    };

    var segCropBox = customGarmentSeg ? cropBox : adjustCropBoxSegPadding(script.cropTexture.control.inputTexture, cropBox);
    updateCrop(script.cropTexture.control, cropBox);
    updateCrop(script.cropSegTexture.control, segCropBox);

    script.dpMLComp.waitOnLoading();
    script.dpMLComp.getInput("driving_image").texture = script.cropTexture;
    script.dpMLComp.getInput("smooth_factor").data.set(new Float32Array([0.0]));
    script.dpMLComp.runImmediate(sync);
}

function prepareWarpGenMLComp() {

    script.warpMLComp.waitOnLoading();
    script.warpMLComp.src_emb = script.dpMLComp.getOutput("drv_emb").data;
    script.warpMLComp.getInput("src_emb").data.set(script.warpMLComp.src_emb);

    if (!settings.skipGenerator) {
        script.warpPostProcessMLComp.waitOnLoading();
        script.warpPostProcessMLComp.getInput("source_image").texture = script.cropTexture;
        script.warpPostProcessMLComp.getInput("source_mask").texture = script.cropSegTexture;
        script.warpPostProcessMLComp.getInput("source_body_seg").data.set(script.dpMLComp.getOutput("driving_body_seg").data);

        script.genMLComp.waitOnLoading();
    }
}

function getTimingsString(times) {
    return "Segmentation: " + (times.seg - times.start) + "ms\n"+
        "SegBox: " + (times.segbox - times.seg) + "ms\n"+
        "DensePose: "+ (times.dp - times.segbox) + "ms\n"+
        "DensePose PostProc: "+ (times.dpPostProc - times.dp) + "ms\n"+
        "Total: "+(times.dpPostProc - times.start) + "ms";
}

function getTimingsJson(times) {
    return {
        segmentation: (times.seg - times.start),
        segbox: (times.segbox - times.seg),
        densepose: (times.dp - times.segbox),
        densepose_pp: (times.dpPostProc - times.dp),
        total: (times.dpPostProc - times.start)
    };
}

script.api.run = function(texture, options, debug) {
    script.segMLComp.onRunningFinished = function() {};
    script.segBoxMLComp.onRunningFinished = function() {};
    script.dpMLComp.onRunningFinished = function() {};

    gridSampleParams = {};

    var times = {};
    times.start = new Date().getTime();
    gridSampleParams.w_without_pad = texture.getWidth();
    gridSampleParams.h_without_pad = texture.getHeight();
    gridSampleParams.w_with_pad = texture.getWidth();
    gridSampleParams.h_with_pad = texture.getHeight();

    script.cropTexture.control.inputTexture = texture;
    if (options.customGarmentSeg) {
        // use custom garment segmentation texture
        script.cropSegTexture.control.inputTexture = options.customGarmentSeg;
        script.segBoxMLComp.getInput("mask").texture = options.customGarmentSeg;
    } else {
        // normal route: run garment(+hair) segmentation
        script.cropSegTexture.control.inputTexture = script.sourceSegTexture;
        runSegMLComp(texture, true);
    }
    times.seg = new Date().getTime();
    runSegBoxMLComp(true);
    times.segbox = new Date().getTime();
    runDPMLComp(true, options.customGarmentSeg);
    times.dp = new Date().getTime();

    var timesString = getTimingsString(times);
    var timesJson = {};
    if (debug) {
        setSourceDebugImages(texture, options);
        timesJson = getTimingsJson(times);
    }

    prepareWarpGenMLComp();
    gridSampleParams.sourceGarmentMask = script.cropSegTexture;

    return {
        success: true,
        times: timesString,
        timesJson: timesJson,
        gridSampleParams: gridSampleParams
    };
};

function setSourceDebugImages(sourceTexture, options) {
    script.debugSourceImage.mainPass.baseTex = sourceTexture;
    if (options.customGarmentSeg) {
        script.debugSourceSegImage.mainPass.baseTex = options.customGarmentSeg;
    } else {
        script.debugSourceSegImage.mainPass.baseTex = script.segMLComp.getOutput("mask_ug").texture;
    }
    script.debugSourceCropImage.mainPass.baseTex = script.cropTexture;

    script.debugSourceSegCropImage.mainPass.tex1 = script.cropTexture;
    script.debugSourceSegCropImage.mainPass.tex2 = script.cropSegTexture;
    script.debugSourceSegCropImage.mainPass.tex2_opacity = 0.5;

    bodySeg = script.dpMLComp.getOutput("driving_body_seg");
    var tex = global.utils.createTextureFromData(bodySeg.data, bodySeg.shape.x, bodySeg.shape.y, 1, 0, 1, false, true);
    script.debugSourceDPImage.mainPass.baseTex = tex;
}

script.api.init = function(opts) {
    settings = opts;
    return true;
};
