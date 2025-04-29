// -----JS CODE-----
// @input Asset.ObjectPrefab faceStretchPrefab;

//@ui {"widget":"label", "label":"Face Deformation Params"}
//@input float enlargeCheekbones = 0.0;
//@input float cheeks = 1.0;
//@input float leftEye = 1.0;
//@input float rightEye = 1.0;
//@input float mouthWidth = 1.0;
//@input float mouthHeight = 1.0;
//@input float nose = 1.0;


const FACEMESH_NAME = 'Face Mesh';

let inputs = {
    Enlarge_cheekbones: script.enlargeCheekbones,
    Cheeks: script.cheeks,
    Left_eye: script.leftEye,
    Mouth_width: script.mouthWidth,
    Mouth_height: script.mouthHeight,
    Nose: script.nose,
    Right_eye: script.rightEye
};

let blendshapes, prefab, names;

function init() {
    if (!validateInputs()) {
        return;
    }
    prefab = script.faceStretchPrefab.instantiate(script.getSceneObject());
    fixRenderLayers(prefab);
    try {
        blendshapes = findChild(prefab, FACEMESH_NAME).getComponent('Component.RenderMeshVisual');
        blendshapes.clearBlendShapeWeights();
        names = blendshapes.getBlendShapeNames();
    } catch (e) {
        print('Face Stretch CC Error: problem instantiating prefab!');
        return;
    }
    initializeProperties();
    setPropertiesAndEvents();
}

function setPropertiesAndEvents() {
    setEnableDisableEvents(prefab);
    bindProperties();
}

function bindProperties() {
    for (const [key, value] of Object.entries(inputs)) {
        let lowerCaseKey = key.toLowerCase();
        bindProperty(lowerCaseKey, inputs);
    }
}

function initializeProperties() {
    for (const [key, value] of Object.entries(inputs)) {
        setBlendShape(key, value);
    }
}

function setBlendShape(featureName, val){
    let blendShapeName;
    featureName = featureName.charAt(0).toUpperCase() + featureName.slice(1);

    if (featureName === 'Enlarge_cheekbones') {
        blendShapeName = 'cheekbones_bigger';
        val = clamp(val, 0, 1.0);
    } else if (featureName === 'Mouth_width') {
        val = clamp(val, 0, 2.0);
        if (val > 1.0) {
            blendShapeName = 'mouth_wider';
            val = val - 1.0; // Normalize the value to the range 0-1
        } else {
            blendShapeName = 'mouth_narrower';
            val = 1.0 - val; // Invert the value for shrinking
        }
    } else if (featureName === 'Mouth_height') {
        val = clamp(val, 0, 2.0);
        if (val > 1.0) {
            blendShapeName = 'mouth_taller';
            val = val - 1.0; // Normalize the value to the range 0-1
        } else {
            blendShapeName = 'mouth_smaller';
            val = 1.0 - val; // Invert the value for shrinking
        }
    } else {
        val = clamp(val, 0, 2.0);
        if (val > 1.0) {
            blendShapeName = featureName + '_bigger';
            val = val - 1.0; // Normalize the value to the range 0-1
        } else {
            blendShapeName = featureName + '_smaller';
            val = 1.0 - val; // Invert the value for shrinking
        }
    }

    blendShapeName = blendShapeName.charAt(0).toUpperCase() + blendShapeName.slice(1);
    blendshapes.setBlendShapeWeight(blendShapeName, val);
}

function validateInputs() {
    if (!isUnderCamera(script.getSceneObject())) {
        print('Face Stretch CC Error: Place under parent camera!');
        return false;
    }
    if (!script.faceStretchPrefab) {
        print('Face Stretch CC Error: Please provide prefab!');
        return false;
    }
    return true;
}

init();

// Helpers

function clamp(num, min, max) {
    return num <= min ? min : num >= max ? max : num;
}

function bindProperty(inputName, obj) {
    let apiName = convertToLowerCamelCase(inputName);
    Object.defineProperty(script, apiName, {
        set: function(val) {
                obj[inputName] = val;
                setBlendShape(inputName, val);
        },
        get: function() {
            inputName = inputName.charAt(0).toUpperCase() + inputName.slice(1);
            return obj[inputName];
        }
    });
}

function convertToLowerCamelCase(str) {
    return str.toLowerCase().replace(/_([a-z])/g, function(match, letter) {
        return letter.toUpperCase();
    });
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

function forEachChild(so, func) {
    func(so);
    for (let i = 0; i < so.getChildrenCount(); i++) {
        forEachChild(so.getChild(i), func);
    }
}

function findChild(root, name) {
    if (root.name == name) {
        return root;
    }
    for (let i = 0; i < root.getChildrenCount(); i++) {
        const child = root.getChild(i);
        let found = findChild(child, name);
        if (found) {
            return found;
        }
    }
    return null;
}

function isUnderCamera(so) {
    if (!so) {
        return null;
    }
    const cam = so.getComponent("Component.Camera");
    if (cam) {
        return cam;
    }
    return isUnderCamera(so.getParent());
}

function setEnableDisableEvents(obj) {
    script.createEvent('OnDisableEvent').bind(function() {
        obj.enabled = false;
    });
    script.createEvent('OnEnableEvent').bind(function() {
        obj.enabled = true;
    });
}