// FaceMask.js
//
// Version 1.0
//
// Face Mask Lens Block for AI Lens Creator
//


//@input Asset.Texture texture
//@input float opacity = 1.0 {"min":0.0, "max":1.0, "step":0.001}
//@input Asset.ObjectPrefab facemaskPrefab

function forEachChild(so, func) {
    func(so);
    for (let i = 0; i < so.getChildrenCount(); i++) {
        forEachChild(so.getChild(i), func);
    }
}

function fixRenderLayers(so) {
    const layer = getCameraRenderLayer(so);
    if (!layer) {
        print("cannot find render layer for camera above so: " + so);
        return;
    }
    assignRenderLayer(so, layer);
}

function assignRenderLayer(root, layer) {
    forEachChild(root, function(so) {
        so.layer = layer;
    });
}

function getCameraRenderLayer(so) {
    const cam = getParentCamera(so);
    if (!cam) {
        print("could not find parent camera for object: " + so.name);
        return null;
    }
    return cam.renderLayer;
}

function getParentCamera(so) {
    if (!so) {
        return null;
    }
    const cam = so.getComponent("Component.Camera");
    if (cam) {
        return cam;
    }
    return getParentCamera(so.getParent());
}

let initialized = false;
let facemaskSo = null;
let facemaskMat = null;
let enableOnTexture = false;

function init() {
    if (initialized) {
        return false;
    }
    
    if (!checkInputs()) {
        return false;
    }
    
    facemaskSo = script.facemaskPrefab.instantiate(script.getSceneObject());
    fixRenderLayers(facemaskSo);
    const comp = facemaskSo.getComponent("Component.FaceMaskVisual");
    facemaskMat = comp.getMaterial(0).clone();
    comp.clearMaterials();
    comp.addMaterial(facemaskMat);
    if (script.texture) {
        facemaskMat.mainPass.baseTex = script.texture;
    } else {
        enableOnTexture = true;
        facemaskSo.enabled = false;
    }
    facemaskMat.mainPass.opacityMul = script.opacity;
    
    setupProperties();
    
    initialized = true;
}

function setupProperties() {
    script.createEvent("OnDisableEvent").bind(function() {
        if (facemaskSo) {
            facemaskSo.enabled = false;
            enableOnTexture = false;
        }
    });
    script.createEvent("OnEnableEvent").bind(function() {
        if (facemaskSo) {
            facemaskSo.enabled = true;
        }
    });
    
    Object.defineProperties(script, {
        texture: {
            set: function(value) {
                if (facemaskMat) {
                    facemaskMat.mainPass.baseTex = value;
                    if (enableOnTexture) {
                        facemaskSo.enabled = true;
                        enableOnTexture = false;
                    }
                }
            },
            get: function() {
                if (facemaskMat) {
                    return facemaskMat.mainPass.baseTex;
                }
            }           

        },
        opacity: {
            set: function(value) {
                if (facemaskMat) {
                    facemaskMat.mainPass.opacityMul = value;
                }
            },
            get: function() {
                if (facemaskMat) {
                    return facemaskMat.mainPass.opacityMul;
                }
            }
        }
    });
}

function checkInputs() {
    if (!script.facemaskPrefab) {
        return false;
    }
    
    return true;
}

init();
