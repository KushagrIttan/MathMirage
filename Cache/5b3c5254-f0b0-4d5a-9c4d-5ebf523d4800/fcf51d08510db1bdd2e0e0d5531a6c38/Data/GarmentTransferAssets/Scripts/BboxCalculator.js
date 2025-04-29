// sharedState is shared with DrivingPrediction.js
var sharedState = {
    drivingTexture: null,
    upperGarmentMaskTexture: null,
    fixCropbox: null,
    warpMLComp: null,
    segBoxMLComp: null
}

script.shareState = function(sharedState_){
    sharedState = sharedState_;
}

// Variables needed for calculating a mask bounding box
var maskBoundingBoxVars = {
    dir_x: new vec3(1, 0, 0),
    dir_y: new vec3(0, 1, 0),
    max_x: new Float32Array(1),
    min_x: new Float32Array(1),
    max_y: new Float32Array(1),
    min_y: new Float32Array(1)
}

var forceDt = null;


// Helper functions for calculating the bbox parameters

const buvBboxConstants = {
    maxSmoothTime: 0.5, // maximum dt for which we still use smoothing
    smoothHighFps: 15, // smoothing alpha interpolation high fps point
    smoothHighFpsAlpha: 0.3, // smoothing alpha coefficient when fps >= smoothHighFps
    smoothLowFps: 5, // smoothing alpha interpolation low fps point
    smoothLowFpsAlpha: 1, // smoothing alpha coefficient when fps <= smoothLowFps

    paddingCoeff: 83 / 800, // padding coefficient, padding is this multiplied by (box_size ^ 2 / frameWidth)
    paddingMin: 3 / 80, // min padding (units of frameWidth)
    paddingMax: 15 / 80, // max padding (units of frameWidth)
    bufferArea: 3 / 80, // if the mask gets close to the edge add extra buffer (units of frameWidth)
    addBufferCoeff: 0.33,  // how much buffer to add
    stayCloseLargerCoeff: 0, // threshold for when box is getting larger, units of padding
    stayCloseSmallerCoeff: 1.2, // threshold for when box is getting smaller, units of padding
    maxStayCloseCoeff: 1 / 8, // maximum "stayClose" region (units of frameWidth)

    fallbackRegion: 0.1, // minimum valid box size, below this we use fallback (units of frame width/height)
    fallbackTimeRegion: 2, // for dt larger than this we use fallback

    min_negative_y_padding: 1.5 // minimum padding for the bottom if outside the box (units of padding)
}

const segBoxBboxConstants = {
    emptyBoxThreshold: 0.015,
    boxSizeStdFactor: 2.8,
    maxSmoothTime: 0.5,
    tauUp: 0.5,
    tauDown: 0.5
}


script.calcCropBox = function(bbox) {
    const frameWidth = sharedState.drivingTexture.getWidth();
    const frameHeight = sharedState.drivingTexture.getHeight();

    // make crop square
    var max_size = Math.max(bbox.y2 - bbox.y, bbox.x2 - bbox.x);
    var pad_y = max_size - (bbox.y2 - bbox.y);
    var pad_x = max_size - (bbox.x2 - bbox.x);

    var y = bbox.y - Math.floor(pad_y / 2);
    var y2 = bbox.y2 + pad_y - Math.floor(pad_y / 2);
    var x = bbox.x - Math.floor(pad_x / 2);
    var x2 = bbox.x2 + pad_x - Math.floor(pad_x / 2);

    if (sharedState.fixCropbox) {
        // translate bbox if part of it is outside the image and part of it inside the image
        var padding_x = x2 - frameWidth;
        var padding_y = y2 - frameHeight;
        var oob_padding_x = Math.max(0, Math.min(x, padding_x));
        var oob_padding_y = Math.max(0, Math.min(y, padding_y));
        oob_padding_x += Math.min(0, Math.max(x, padding_x));
        oob_padding_y += Math.min(0, Math.max(y, padding_y));

        x -= oob_padding_x;
        y -= oob_padding_y;
        x2 -= oob_padding_x;
        y2 -= oob_padding_y;
    }

    // Compute driving frame cropping values in [-1, 1]
    var crop_left = (x / frameWidth) * 2 - 1;
    var crop_right = (x2 / frameWidth) * 2 - 1;
    var crop_bottom = (y / frameHeight) * 2 - 1;
    var crop_top = (y2 / frameHeight) * 2 - 1;

    bbox.x = x;
    bbox.y = y;
    bbox.x2 = x2;
    bbox.y2 = y2;
    bbox.crop_left = crop_left;
    bbox.crop_right = crop_right;
    bbox.crop_bottom = crop_bottom;
    bbox.crop_top = crop_top;

    return bbox;
}


script.calcMaskCropBox = function(boxDims) {
    var boxSize = boxDims.x2 - boxDims.x;
    var widthRatio = sharedState.upperGarmentMaskTexture.getWidth() / sharedState.drivingTexture.getWidth();
    var heightRatio = sharedState.upperGarmentMaskTexture.getHeight() / sharedState.drivingTexture.getHeight();

    // Compute driving mask frame values in pixels
    var x = Math.floor(boxDims.x * widthRatio);
    var y = Math.floor(boxDims.y * heightRatio);
    var max_w = Math.floor(boxSize * widthRatio);
    var max_h = Math.floor(boxSize * heightRatio);

    // Compute driving frame mask pads values in pixels
    var x_pad = -Math.min(x, 0);
    var y_pad = -Math.min(y, 0);
    var x2 = x + max_w;
    var y2 = y + max_h;


    // Compute driving mask frame values within frame (till now, values could deviate from frame)
    x = Math.max(0, Math.min(x, sharedState.upperGarmentMaskTexture.getWidth()));
    y = Math.max(0, Math.min(y, sharedState.upperGarmentMaskTexture.getHeight()));
    x2 = Math.max(0, Math.min(x2, sharedState.upperGarmentMaskTexture.getWidth()));
    y2 = Math.max(0, Math.min(y2, sharedState.upperGarmentMaskTexture.getHeight()));
    const w = x2 - x;
    const h = y2 - y;

    return {
        x_pad: x_pad,
        y_pad: y_pad,
        x: x,
        y: y,
        w: w,
        h: h,
        max_h: max_h,
        max_w: max_w
    };
}


function buvBboxGetTarget(cropInfo, padding) {
    // helper function for buvBbox; get the "buffer target", which is the area that if the tight cropbox gets near to,
    // we want to add additional padding so we will catch fast movements.
    var buffer_target = {x: cropInfo.x,
                         y: cropInfo.y,
                         x2: cropInfo.x + cropInfo.box_size,
                         y2: cropInfo.y + cropInfo.box_size};

    // if the previous cropbox was larger, we do not want to add this extra buffer
    if (cropInfo.prevCropInfo !== null) {
        buffer_target.x = Math.min(buffer_target.x, cropInfo.prevCropInfo.x);
        buffer_target.y = Math.min(buffer_target.y, cropInfo.prevCropInfo.y);
        buffer_target.x2 = Math.max(buffer_target.x2, cropInfo.prevCropInfo.x + cropInfo.prevCropInfo.box_size);
        buffer_target.y2 = Math.max(buffer_target.y2, cropInfo.prevCropInfo.y + cropInfo.prevCropInfo.box_size);
    }

    // compare with the bbox_target (i.e where we want to be before smoothing) and not where the current cropbox is
    if (cropInfo.bbox_target != null) {
        buffer_target.x = Math.min(buffer_target.x, cropInfo.bbox_target.x + padding);
        buffer_target.y = Math.min(buffer_target.y, cropInfo.bbox_target.y + padding);
        buffer_target.x2 = Math.max(buffer_target.x2, cropInfo.bbox_target.x2 - padding);
        buffer_target.y2 = Math.max(buffer_target.y2, cropInfo.bbox_target.y2 - padding);
    }
    return buffer_target;
}


function buvBboxStayCloseInternal(cropInfo, padding, add_buffer_log) {
    // helper function for buvBbox; this returns a function that checks if a side of the bbox did not move too much,
    // we just leave it in the previous value.
    var C = buvBboxConstants;

    var frameWidth = sharedState.drivingTexture.getWidth()
    var stayCloseLarger = Math.min(padding * C.stayCloseLargerCoeff, C.maxStayCloseCoeff * frameWidth);
    var stayCloseSmaller = Math.min(padding * C.stayCloseSmallerCoeff, C.maxStayCloseCoeff * frameWidth);

    // c_{x,y,x2,y2} are the values we compare to
    var comparison = {
        x : cropInfo.x,
        y : cropInfo.y,
        x2 : cropInfo.x + cropInfo.box_size,
        y2 : cropInfo.y + cropInfo.box_size,
        prev : null
    }

    if (cropInfo.bbox_target != null) {
        comparison = {
            x : cropInfo.bbox_target.x,
            y : cropInfo.bbox_target.y,
            x2 : cropInfo.bbox_target.x2,
            y2 : cropInfo.bbox_target.y2,
            prev : null
        }
    }

    // we also compare to the previous cropbox to avoid jitter
    var prevCropInfo = cropInfo.prevCropInfo
    if (prevCropInfo != null) {
        comparison.prev = {
            x : prevCropInfo.x,
            y : prevCropInfo.y,
            x2 : prevCropInfo.x + prevCropInfo.box_size,
            y2 : prevCropInfo.y + prevCropInfo.box_size
        }
        if (prevCropInfo.bbox_target != null) {
            comparison.prev = {
                x : prevCropInfo.bbox_target.x,
                y : prevCropInfo.bbox_target.y,
                x2 : prevCropInfo.bbox_target.x2,
                y2 : prevCropInfo.bbox_target.y2
            }
        }
    }

    function stayClose(coord, val, direction) {
        // if `val` is projected to move less than a given threshold, do not move it.
        // if there was an added buffer to this coordinate - always move it.

        if (add_buffer_log[coord]) {
            return val
        }

        if (direction == "larger") {
            // for the cropbox to get larger, x and y become smaller
            var region = stayCloseLarger;
            var coordIsSmaller = (coord == "x") || (coord == "y");
        } else if (direction == "smaller") {
            // for the cropbox to get smaller, x2 and y2 become smaller
            var region = stayCloseSmaller;
            var coordIsSmaller = (coord == "x2") || (coord == "y2");
        } else {
            throw "Error: direction unknown << " + direction
        }

        if (coordIsSmaller) {
            if ((val < comparison[coord]) && (val + region > comparison[coord])) {
                if (comparison.prev == null ||
                    ((val < comparison.prev[coord]) && (val + region > comparison.prev[coord]))) {
                        return comparison[coord];
                }
            }
        } else {
            if ((val > comparison[coord]) && (val - region < comparison[coord])) {
                if (comparison.prev == null ||
                    ((val > comparison.prev[coord]) && (val - region < comparison.prev[coord]))) {
                        return comparison[coord];
                }
            }
        }

        return val;
    }

    return stayClose;
}


function buvBboxStayClose(cropInfo, bbox, dt, padding, add_buffer_log) {
    // Step 5. If any of the edges are too close to the location of the previous frame or the one before that,
    // use the previous frame's value instead of the new value. This makes the box very temporally stable.
    if (dt > 0 && dt < buvBboxConstants.maxSmoothTime) {
        var stayClose = buvBboxStayCloseInternal(cropInfo, padding, add_buffer_log);

        for (var i=0; i<2; i++) {
            var direction = ["larger", "smaller"][i];
            bbox.x = stayClose("x", bbox.x, direction);
            bbox.y = stayClose("y", bbox.y, direction);
            bbox.x2 = stayClose("x2", bbox.x2, direction);
            bbox.y2 = stayClose("y2", bbox.y2, direction);
        }
    }
}


function buvBboxAddBuffer(cropInfo, bbox, padding) {
    // step 3: If the box is too close to any of the edges - add buffer to this edge.
    // here we also check for the box "target" location which is the output that should have been if there
    // was no temporal smoothing applied, and also the previous box location.
    var add_buffer = padding * buvBboxConstants.addBufferCoeff;
    var bufferArea = buvBboxConstants.bufferArea * sharedState.drivingTexture.getWidth();
    var add_buffer_log = {x: false, y: false, x2: false, y2: false};
    var buffer_target = buvBboxGetTarget(cropInfo, padding);

    // do the buffer addition
    if (bbox.y - buffer_target.y < bufferArea) { bbox.y -= add_buffer; add_buffer_log.y = true;};
    if (bbox.x - buffer_target.x < bufferArea) { bbox.x -= add_buffer; add_buffer_log.x = true;};
    if (buffer_target.y2 - bbox.y2 < bufferArea) { bbox.y2 += add_buffer; add_buffer_log.y2 = true;};
    if (buffer_target.x2 - bbox.x2 < bufferArea) { bbox.x2 += add_buffer; add_buffer_log.x2 = true;};

    return add_buffer_log;
}


function buvBboxAddPadding(bbox, padding) {
    // Step 4: Add padding to all edges.
    if (padding > 0) {
        bbox.y = bbox.y - padding;
        bbox.y2 = bbox.y2 + padding;
        bbox.x = bbox.x - padding;
        bbox.x2 = bbox.x2 + padding;
    }

    if (bbox.y < 0){
        bbox.y = Math.min(bbox.y, -padding * buvBboxConstants.min_negative_y_padding)
    }
}


function buvBboxTemporalSmoothing(cropInfo, bbox, dt, add_buffer_log) {
    //  Step 6. Do temporal-smoothing with the previous edge location.
    if (cropInfo.pre_square_vals != null && dt > 0 && dt < buvBboxConstants.maxSmoothTime) {
        // wanted smoothHighFps --> alpha = smoothHighFpsAlpha
        // wanted smoothLowFps --> alpha = smoothLowFpsAlpha
        // alpha ~ a * e^(dt * b)

        var a1 = 1 / buvBboxConstants.smoothHighFps;
        var a2 = 1 / buvBboxConstants.smoothLowFps;
        var highFpsFactor = Math.pow(buvBboxConstants.smoothHighFpsAlpha, (a2 - dt) / (a2 - a1))
        var lowFpsFactor = Math.pow(buvBboxConstants.smoothLowFpsAlpha, (a1 - dt) / (a1 - a2))
        var alpha = highFpsFactor * lowFpsFactor;
        alpha = Math.min(Math.max(alpha, buvBboxConstants.smoothHighFpsAlpha), buvBboxConstants.smoothLowFpsAlpha);
        if (!add_buffer_log.x) {bbox.x = bbox.x * alpha + cropInfo.pre_square_vals.x * (1 - alpha)}
        if (!add_buffer_log.y) {bbox.y = bbox.y * alpha + cropInfo.pre_square_vals.y * (1 - alpha)}
        if (!add_buffer_log.x2) {bbox.x2 = bbox.x2 * alpha + cropInfo.pre_square_vals.x2 * (1 - alpha)}
        if (!add_buffer_log.y2) {bbox.y2 = bbox.y2 * alpha + cropInfo.pre_square_vals.y2 * (1 - alpha)}
    }
}


function buvBboxHandleFallback(bbox, frameWidth, frameHeight) {
    //  Step 7. if the result is too small - fallback.
    var fallback = (bbox.x2 - bbox.x < buvBboxConstants.fallbackRegion * frameWidth) ||
                   (bbox.y2 - bbox.y < buvBboxConstants.fallbackRegion * frameHeight);
    if (fallback) {
        bbox.x = 0;
        bbox.y = 0;
        bbox.x2 = frameWidth;
        bbox.y2 = frameHeight;
    }
    return fallback;
}

script.setMaskBoundingBoxVars = function(mask_dims) {
    maskBoundingBoxVars.mask_dims = mask_dims;
    maskBoundingBoxVars.single_dim = new vec3(mask_dims.x, 1, 1);
    maskBoundingBoxVars.grid_ascending = new Float32Array(mask_dims.x);
    maskBoundingBoxVars.grid_descending = new Float32Array(mask_dims.x);
    maskBoundingBoxVars.single_axis_arr = new Float32Array(mask_dims.x);
    maskBoundingBoxVars.single_axis_arr2 = new Float32Array(mask_dims.x);
    maskBoundingBoxVars.bbox_mask_arr = new Float32Array(mask_dims.x * mask_dims.y);

    for (var _i=0; _i<mask_dims.x; _i++) {
        maskBoundingBoxVars.grid_ascending[_i] = (_i+1) / mask_dims.x;
        maskBoundingBoxVars.grid_descending[_i] = 1 - (_i / mask_dims.x);
    }
}

script.setForceDt = function(setForceDt) {
    forceDt = setForceDt;
}

function calc_bbox(bbox_mask) {
    // Threshold the mask
    c = maskBoundingBoxVars;
    TensorMath.applyThreshold(bbox_mask, 127.5, 1, TensorMath.ThresholdMethod.Binary, c.bbox_mask_arr);

    // Calculate x bound
    TensorMath.sum(c.bbox_mask_arr, c.mask_dims, c.dir_x, c.single_axis_arr);
    TensorMath.applyThreshold(c.single_axis_arr, 0.5, 1, TensorMath.ThresholdMethod.Binary, c.single_axis_arr);

    TensorMath.mulTensors(c.single_axis_arr, c.single_dim, c.grid_ascending, c.single_dim, c.single_axis_arr2);
    TensorMath.max(c.single_axis_arr2, c.single_dim, c.max_x)

    TensorMath.mulTensors(c.single_axis_arr, c.single_dim, c.grid_descending, c.single_dim, c.single_axis_arr2);
    TensorMath.max(c.single_axis_arr2, c.single_dim, c.min_x)

    // Calculate y bound
    TensorMath.sum(c.bbox_mask_arr, c.mask_dims, c.dir_y, c.single_axis_arr);
    TensorMath.applyThreshold(c.single_axis_arr, 0.5, 1, TensorMath.ThresholdMethod.Binary, c.single_axis_arr);

    TensorMath.mulTensors(c.single_axis_arr, c.single_dim, c.grid_ascending, c.single_dim, c.single_axis_arr2);
    TensorMath.max(c.single_axis_arr2, c.single_dim, c.max_y);

    TensorMath.mulTensors(c.single_axis_arr, c.single_dim, c.grid_descending, c.single_dim, c.single_axis_arr2);
    TensorMath.max(c.single_axis_arr2, c.single_dim, c.min_y)

    return [
        1 - c.min_y[0],
        1 - c.min_x[0],
        c.max_y[0],
        c.max_x[0]
    ]
}

script.buvBbox = function(cropInfo) {
    // This function calculates the bbox from the bodyUV output of the previous frame
    //
    // Algorithm description:
    //  1. If too much time passed from prev frame, fallback.
    //  2. Get the tight upper-body box of the previous frame from the warping component as an initial value
    //     for the next crop-box.
    //  3. If the box is too close to any of the edges - add buffer to this edge. *
    //  4. Add padding to all edges.
    //
    //  The following two steps (5-6) only apply to edges that did not get additional buffer in step 3:
    //
    //  5. If any of the edges are too close to the location of the previous frame or the one before that*,
    //     use the previous frame's value instead of the new value. This makes the box very temporally stable.
    //  6. Do temporal-smoothing with the previous edge location.
    //
    //  * in step 3 and 5 we also check for the box "target" location which is the output that should have been if there
    //    was no temporal smoothing applied, and also the previous box location.
    //
    //  7. if the result is too small - fallback.
    //

    const frameWidth = sharedState.drivingTexture.getWidth();
    const frameHeight = sharedState.drivingTexture.getHeight();
    var time = getTime(); // in seconds.
    var C = buvBboxConstants;

    // step 1: fallback when no prev cropInfo available or too much time passed
    if (cropInfo == null || time - cropInfo.time > C.fallbackTimeRegion) {
        return {
            x: 0,
            y: 0,
            x2: frameWidth,
            y2: frameHeight,
            fallback: true
        };
    }

    var dt = (forceDt == null) ?  time - cropInfo.time : forceDt;

    var padding =  (cropInfo.box_size ** 2 / frameWidth) * C.paddingCoeff;
    padding = Math.min(Math.max(padding, C.paddingMin * frameWidth), C.paddingMax * frameWidth);
    var bbox_normalized = calc_bbox(sharedState.warpMLComp.getOutput("bbox_mask").data);


    // Step 2. Get the tight upper-body box of the previous frame
    // the y-axis is mirrored because of how LS represents images
    var bbox = {x: bbox_normalized[1] * cropInfo.box_size + cropInfo.x,
                y: (1 - bbox_normalized[2]) * cropInfo.box_size + cropInfo.y,
                x2: bbox_normalized[3] * cropInfo.box_size + cropInfo.x,
                y2: (1 - bbox_normalized[0]) * cropInfo.box_size + cropInfo.y}

    // Step 3. When the mask gets to the very end of the crop-box, we give some extra buffer so we could catch fast
    // movements. `add_buffer_log` marks edges that we not do temporal smoothing with.
    var add_buffer_log = buvBboxAddBuffer(cropInfo, bbox, padding);

    // Step 4. Add padding
    buvBboxAddPadding(bbox, padding);

    // Step 5. If cropbox did not change much, leave it in place
    buvBboxStayClose(cropInfo, bbox, dt, padding, add_buffer_log);

    // bbox_target is the pre-smoothing values, i.e. the target to the smoothing
    var bbox_target = {x: bbox.x, x2: bbox.x2, y: bbox.y, y2: bbox.y2}

    // Step 6. Exponential temporal smoothing
    buvBboxTemporalSmoothing(cropInfo, bbox, dt, add_buffer_log);

    // save the values before the square for the smoothing
    var pre_square_vals = {x: bbox.x, x2: bbox.x2, y: bbox.y, y2: bbox.y2}

    // Round
    bbox.x = Math.round(bbox.x);
    bbox.x2 = Math.round(bbox.x2);
    bbox.y = Math.round(bbox.y);
    bbox.y2 = Math.round(bbox.y2);

    // Step 7. fallback when box is too small
    var fallback = buvBboxHandleFallback(bbox, frameWidth, frameHeight);

    return {
        x: bbox.x,
        y: bbox.y,
        x2: bbox.x2,
        y2: bbox.y2,
        pre_square_vals: pre_square_vals,
        bbox_target: bbox_target,
        fallback: fallback
    };
}


script.segmentationBbox = function(cropInfo, fallback) {
    // This function calculates the bbox from the upper-garment segmentation of the current frame
    // fallback is a boolean that marks this run as a fallback to buvBbox()

    var C = segBoxBboxConstants;
    const frameWidth = sharedState.drivingTexture.getWidth();
    const frameHeight = sharedState.drivingTexture.getHeight();
    var time = getTime(); // in seconds.

    // box[0] and box[1] are the x, y coordinates of the upper garment box center
    // box[2] and box[3] are the x-axis and y-axis variances of the upper garment box
    var box = sharedState.segBoxMLComp.getOutput("box").data;
    // print("segBoxMLComp Box: " + box[0] + "," + box[1] + "," + box[2] + "," + box[3]);

    // Check if SegBox is empty (because segmentation is empty after hard threshold)
    // Or if SegBox returns a box too small (in case of single pixels in hard mask)
    if (box[2] < C.emptyBoxThreshold || box[3] < C.emptyBoxThreshold) {
        // This will lead to width and height of 1.0 after the factor multiplication
        box[0] = 0;
        box[1] = 0;
        box[2] = (1 / C.boxSizeStdFactor);
        box[3] = (1 / C.boxSizeStdFactor);
        fallback = true;
    }

    // Compute raw width and height with factor (box[2] is half the box width;
    // so, for example, factor of 2.5 means enlargment by 25%)
    var w_raw = C.boxSizeStdFactor * box[2];
    var h_raw = C.boxSizeStdFactor * box[3];

    // Temporal filtering
    // disable temporal filtering when in fallback mode
    if (!fallback && cropInfo) {
        var dt = (forceDt == null) ? time - cropInfo.time : forceDt;
        if (dt > 0 && dt < C.maxSmoothTime) {
            var a_up = Math.exp(- dt / C.tauUp);
            var a_down = Math.exp(- dt / C.tauDown);
            var dw = cropInfo.w_raw - w_raw;
            var dh = cropInfo.h_raw - h_raw;
            if (dw < 0) {
                dw = dw * a_up;
            } else {
                dw = dw * a_down;
            }
            if (dh < 0) {
                dh = dh * a_up;
            } else {
                dh = dh * a_down;
            }
            w_raw = w_raw + dw;
            h_raw = h_raw + dh;
        }
    }


    // clamp width and height to not be larger than the image
    if (sharedState.fixCropbox) {
        w_raw = Math.min(w_raw, 1);
        h_raw = Math.min(h_raw, 1);
    }

    var x_normalized = (box[0] + 1) / 2 - w_raw / 2;
    var y_normalized = (-box[1] + 1) / 2 - h_raw / 2;

    var x = Math.floor(x_normalized * frameWidth);
    var y = Math.floor(y_normalized * frameHeight);
    var w = Math.ceil(w_raw * frameWidth);
    var h = Math.ceil(h_raw * frameHeight);
    var x2 = x + w;
    var y2 = y + h;

    return {
        x: x,
        y: y,
        x2: x2,
        y2: y2,
        w_raw: w_raw,
        h_raw: h_raw,
        fallback: fallback
    };
}


script.cropInfoPostProcess = function(prevCropInfo, bbox, boxDims, USE_BUV_BBOX) {
    // Do postprocessing operation on the bbox, such as saving history or removing it in-case of a fallback, and update
    // cropInfo.

    if (prevCropInfo !== null) {
        prevCropInfo.prevCropInfo = null
    }

    var cropInfo = {
        x: boxDims.x,
        y: boxDims.y,
        box_size: boxDims.x2 - boxDims.x,
        time: getTime(),
        prevCropInfo: prevCropInfo
    };

    if (USE_BUV_BBOX) {
        if (bbox.fallback) {
            // in fallback mode, remove all history information
            cropInfo.prevCropInfo = null;
            cropInfo.pre_square_vals = null;
            cropInfo.bbox_target = null;
        } else {
            cropInfo.pre_square_vals = bbox.pre_square_vals;
            cropInfo.bbox_target = bbox.bbox_target;
        }
    } else {
        cropInfo.w_raw = bbox.w_raw;
        cropInfo.h_raw = bbox.h_raw;
    }
    return cropInfo;
}