// Ears3D.js
//
// Version 1.0
//

//@input Asset.ObjectPrefab model;
//@input Asset.ObjectPrefab bindingPrefab;
//@input Asset.Material hair_mat
//@input bool is_dynamic;

let script_so = script.getSceneObject();

let device_tracking = script_so.createComponent("Component.DeviceTracking");
device_tracking.requestDeviceTrackingMode(DeviceTrackingMode.Rotation);
device_tracking.rotationOptions.invertRotation = true;

// Get camera
let camera_so = script_so;
let camera = undefined;
while (camera_so) {
  camera = camera_so.getComponent("Component.Camera");
  if (camera) {
    break;
  }
  camera_so = camera_so.getParent();
}

let binding_so = script.bindingPrefab.instantiate(camera_so);
let anchor_t = binding_so.getTransform();


let hair_binding_so = undefined;
let neck_binding_so = undefined;

{
  let q = [binding_so];
  while (q.length > 0) { 
    let curr_so = q.pop();
    curr_so.layer = camera.renderLayer;

    if (curr_so.name === "hair_binding") {
      hair_binding_so = curr_so;
    }

    if (curr_so.name === "Neck occluder") {
      neck_binding_so = curr_so;
    }

    for (let i_child = 0; i_child < curr_so.getChildrenCount(); ++i_child) {
      q.push(curr_so.getChild(i_child));
    }
  }
}

let hair_so = undefined;

let hair_t = undefined;
let delayed_rot   = undefined; 
let delayed_pos   = undefined; 
let delayed_scale = undefined; 

let hair_mat = undefined;

function instansiate_hair(model_prefab) {
  hair_so = model_prefab.instantiate(hair_binding_so);
  // Init model trans to identy
  
  {
    let q = [hair_so];
    while (q.length > 0) {
      let curr_so = q.pop();
      let curr_so_t = hair_so.getTransform();
      curr_so_t.setLocalScale(new vec3(1, 1, 1));
      curr_so_t.setLocalPosition(new vec3(0, 0, 0));
      curr_so_t.setLocalRotation(quat.quatIdentity());

      if (curr_so.name == "C_hair_GEO") {
        let mesh = curr_so.getComponents("Component.RenderMeshVisual")[0];
        let material = mesh.getMaterial(0);
        let texture = material.mainPass.baseColorTexture;
        hair_mat = script.hair_mat.clone();
        hair_mat.mainPass.baseTex = texture;
        mesh.clearMaterials();
        mesh.addMaterial(hair_mat);
        hair_t = curr_so.getTransform();
      }
            
      let skin_components = curr_so.getComponents("Component.Skin");
      for (let i_skin = 0; i_skin < skin_components.length; ++i_skin){
        skin_components[i_skin].destroy();
      }

      curr_so.layer = camera.renderLayer;
      for(let i_child = 0; i_child < curr_so.getChildrenCount(); ++i_child) {
        q.push(curr_so.getChild(i_child));
      }
    }
  }

  delayed_rot   = hair_t.getWorldRotation();
  delayed_pos   = hair_t.getWorldPosition();
  delayed_scale = hair_t.getWorldScale();

}

instansiate_hair(script.model);


let first_run = true;
// Properties
script.createEvent("OnDisableEvent").bind(function() {
  first_run = false;
  hair_binding_so.enabled = false;
});
script.createEvent("OnEnableEvent").bind(function() {
  hair_binding_so.enabled = true;
});


let curr_model_prefab = script.model;
Object.defineProperties(script, {
  model: {
    set: function(value) {
      if (hair_so) {
        hair_so.destroy();
      }
      curr_model_prefab = value;
      instansiate_hair(curr_model_prefab);
    },
    get: function() {
      return curr_model_prefab;
    }
  },
  isDynamic: {
    set: function(value) { script.is_dynamic = value;},
    set: function() { return script.is_dynamic;}
  }
});

let delayed_trans_obj = global.scene.createSceneObject("NewObject");
let delayed_trans = delayed_trans_obj.getTransform();


let start_delay = false;
script.createEvent("UpdateEvent").bind(function(eventData) {
    
  let curr_rot   = hair_t.getWorldRotation();
  let curr_pos   = hair_t.getWorldPosition();
  let curr_scale = hair_t.getWorldScale();
  
  let dist_to_delay = curr_pos.sub(delayed_pos).length;
    
  if (dist_to_delay > 10){
    start_delay = false;
  }
  
  if (!start_delay && dist_to_delay < 1) {
    start_delay = true;
  }
   
    
  let a = 0.68;
    
  if (!script.is_dynamic || !start_delay) {
   a = 0;
  }
  
  delayed_rot   = quat.slerp(delayed_rot, curr_rot, 1 - a);
  delayed_pos   = delayed_pos.uniformScale(a).add(curr_pos.uniformScale(1 - a));
  delayed_scale = delayed_scale.uniformScale(a).add(curr_scale.uniformScale(1 - a));

  delayed_trans.setWorldRotation(delayed_rot);
  delayed_trans.setWorldScale(delayed_scale);
  delayed_trans.setWorldPosition(delayed_pos);

  hair_mat.mainPass.mat         = delayed_trans.getWorldTransform();
  hair_mat.mainPass.ceneter_pos = anchor_t.getWorldPosition();     
  hair_mat.mainPass.use_dynamic = script.is_dynamic;

  let device_orientation = device_tracking.getTransform().getWorldRotation();

  neck_binding_so.getTransform().setWorldRotation(device_orientation);
});
