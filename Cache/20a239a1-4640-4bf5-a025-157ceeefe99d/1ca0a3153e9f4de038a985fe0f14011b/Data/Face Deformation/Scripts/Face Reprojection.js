// Face Reprojection.js
// Version 0.0.1
// Creates a projection texture from users face onto the extrnal mesh UV set

//@input Asset.Texture outputTexture {"label": "Output Texture"}
//@input Asset.RenderMesh customRenderMesh {"label": "Mesh"}
//@input int faceIndex {"label": "Face Index"}
//@input bool advancedSetup
//@input float targetCaptureCos {"showIf":"advancedSetup", "label": "Capture Threshold" }
//@input Asset.Material projectionMat {"showIf":"advancedSetup", "label": "Projection Material"}

const OFFSET = new vec3(0.0, 0.0, -100.0);
var TrackingMult = { ONE_FACE: 0, TWO_FACES: 1 };

var ReprojectionFace = function() {
    this.captureCos = -1.0;
    this.captureOffScreen = 1.0;
    this.targetCaptureCos = script.targetCaptureCos;
    this.captureCosLerpSpeed = 0.1;
    this.trackingMult = TrackingMult.ONE_FACE;

    this.init = function() {        
        // find render layer that is not yet used in project
        this.unionLayerSet;
        this.createLayerSetRecursively(this);
        this.renderLayer = this.findEmptyRenderLayer(this.unionLayerSet);
        
        this.mainCamera = this.createCameraFromRenderLayer(this.renderLayer);
        //create copy and set material
        this.material = script.projectionMat.clone();
        this.material.baseTexture = this.mainCamera.renderTarget;
        this.pass = this.material.mainPass;

        this.mainCamera.renderTarget = script.outputTexture;
        this.mainCamera.inputTexture = script.outputTexture;
        this.mainCameraTransform = this.mainCamera.getSceneObject().getTransform();

        this.trackingSO = this.getTrackingSO();
        this.transform = this.trackingSO.getTransform();
        this.head = this.trackingSO.getComponent("Component.Head");
        this.renderMesh = script.customRenderMesh;
        this.renderMesh.control.faceIndex = script.faceIndex;

        this.projectionSO = this.createProjectionSO(this.renderLayer, this.material, this.renderMesh);
        this.projTransform = this.projectionSO.getTransform();
        this.mtxWorldInv = this.projTransform.getInvertedWorldTransform();

        this.mtxProjection = mat4.perspective(this.mainCamera.fov, this.mainCamera.aspect, this.mainCamera.near, this.mainCamera.far);
        this.camTransform = this.mainCamera.getTransform();
        this.mtxView = this.camTransform.getInvertedWorldTransform();

    };

    this.createChildSceneObject = function(parentSO) {
        var newSO = scene.createSceneObject("");
        newSO.setParent(parentSO);
        return newSO;
    };

    this.createCameraFromRenderLayer = function(renderLayer) {
        var cameraSO = scene.createSceneObject("cam_" + renderLayer.toString());
        var camera = cameraSO.createComponent("Camera");
        camera.renderLayer = renderLayer;
        camera.near = 1.0;
        camera.far = 1000.0;
        camera.devicePropertyUsage = Camera.DeviceProperty.All;
        return camera;
    };

    this.createMeshVisual = function(layerId, material, renderMesh) {
        var meshSO = scene.createSceneObject("");
        meshSO.layer = layerId;
        var meshVisual = meshSO.createComponent("MeshVisual");
        meshVisual.mesh = renderMesh;
        meshVisual.mainMaterial = material;
        return meshVisual;
    };

    this.getTrackingSO = function() {
        var trackingSO = this.createChildSceneObject(this.mainCamera.getSceneObject());
        var head = trackingSO.createComponent("Component.Head");
        head.setAttachmentPointType(AttachmentPointType.HeadCenter);
        head.faceIndex = script.faceIndex;
        return trackingSO;
    };

    this.createProjectionSO = function(renderLayer, material, renderMesh) {
        var newMV = this.createMeshVisual(renderLayer, material, renderMesh);
        newMV.getSceneObject().getTransform().setWorldPosition(this.mainCameraTransform.getWorldPosition().add(OFFSET));
        return newMV;
    };

    this.dfs = function(sceneObject, func, context) {
        var result = null;
        result = func(sceneObject, context);
        for (var i = 0; i < sceneObject.getChildrenCount(); i++) {
            var childRes = context.dfs(sceneObject.getChild(i), func, context);
            if (childRes) {
                result = childRes;
            }
        }
        return result;
    };

    this.createLayerSetRecursively = function(context) {
        var resultObject = null;
        for (var i = 0; i < global.scene.getRootObjectsCount(); i++) {
            var rootResult = context.dfs(global.scene.getRootObject(i), context.createUnionLayerSet, context);
            if (rootResult) {
                resultObject = rootResult;
            }
        }
        if (!resultObject) {
            print("[Face Reprojection], WARNING, No Cameras with LayerSets found!");
        }
        return resultObject;
    };

    this.createUnionLayerSet = function(SO, context) {
        var cam = SO.getComponent("Camera");
        if (cam == null) {
            return null;
        }
        context.unionLayerSet = context.unionLayerSet == null ? cam.renderLayer : context.unionLayerSet.union(cam.renderLayer);
        return context.unionLayerSet;
    };

    this.findEmptyRenderLayer = function(unionLayerSet) {
        for (var bit = 0; bit < 32; ++bit) {
            var newLayerSet = LayerSet.fromNumber(bit);
            if (newLayerSet.intersect(unionLayerSet).isEmpty()) {
                return newLayerSet;
            }
        }
        print("[Face Reprojection], WARNING, No empty layers left in project!");
        return null;
    };

    this.lerp = function(a, b, t) {
        return (a * (1.0 - t) + b * t);
    };

    this.updateScene = function() {
        if (this.trackingMult == TrackingMult.TWO_FACES) {
            this.captureOffScreen = 0.0;
        }
        this.mtxProjection = mat4.perspective(this.mainCamera.fov, this.mainCamera.aspect, this.mainCamera.near, this.mainCamera.far);
        this.mtxView = this.camTransform.getInvertedWorldTransform();
        this.mtxWorldInv = this.projTransform.getInvertedWorldTransform();
        this.mtxWorld = this.transform.getWorldTransform();
        this.mtxSaved = this.mtxProjection.mult(this.mtxView).mult(this.mtxWorld);

        // Always need to multiply by the current (not saved!) inverse world transform. 
        // This is because positions in the shader are already in world space, and you need to 
        // get them back to object space, so that saved worldViewProjection transforms work correctly
        this.mtxFinal = this.mtxSaved.mult(this.mtxWorldInv);
        this.pass.uv2Matrix = this.mtxProjection;
        this.pass.captureCos = this.captureCos;
        this.pass.captureOffScreen = this.captureOffScreen;
        this.pass.realModelMatrix = this.mtxWorld;
        this.pass.perspCameraWorldPos = this.camTransform.getWorldPosition();

        if (this.trackingMult == TrackingMult.TWO_FACES) {
            this.captureCos = this.lerp(this.captureCos, this.targetCaptureCos, this.captureCosLerpSpeed);
        }
        this.trackingMult = this.head.getFacesCount() < 2 ? TrackingMult.ONE_FACE : TrackingMult.TWO_FACES;
        this.pass.trackingMult = this.trackingMult;
    };
    this.init();
};

var reprojection = new ReprojectionFace();

script.createEvent("UpdateEvent").bind(function() {
    reprojection.updateScene();
});
