/**
 * @module DestructionHelper
 * Module providing helpers for what to do when a script or custom component is destroyed.
 * @author Snap Inc.
 * @version 1.0.0
 * 
 * ====  Example ====
 * @example
 *
 * // Import module
 * var DestructionHelper = require("./DestructionHelper");
 * 
 * //Create a helper instance for your script
 * var manager = new DestructionHelper(script);
 *
 * //Wrap a callback
 * var reg = script.interactionComponent.onTouchStart.add(manager.safeCallback(function() {
 *      ...
 * }));
 *
 * //Create a SceneObject that will be destroyed when the script is
 * var obj = manager.createSceneObject(null);
 * ====  API ====
 * @api
 * 
 * safeCallback(function callback): function
 *      Takes a function that will only be called if the script has not been destroyed.
 *      Returns a function to be passed to other API
 * 
 * createComponent(SceneObject obj, string type): Component
 *      Creates a Component of type type on the given obj. 
 *      It will be destroyed when the script is
 * 
 * createSceneObject(SceneObject parent): SceneObject
 *      Creates a SceneObject with the given parent. 
 *      It will be destroyed when the script is
 *
 */

/**
 * @class
 * @param {ScriptComponent} inputScript 
 */
function DestructionHelper(inputScript) {
    var manager = this;
    manager._isAlive = true;
    manager._toDestroy = [];
    inputScript.createEvent("OnDestroyEvent").bind(function() {
        manager._isAlive = false;
        manager._toDestroy.forEach(function(element) {
           if(!isNull(element)) {
                element.destroy();
           } 
        });
    })
};

/**
 * Takes a function that will only be called if the script has not been destroyed.
 * Returns a function to be passed to other API.
 * @template {function} T
 * @param {T} callback 
 * @returns {T}
 */
DestructionHelper.prototype.safeCallback = function(callback) {
    var manager = this;
    return function() {
        if(manager._isAlive) {
            callback.apply(null, arguments);
        }
    };
}

/**
 * Creates a Component of type `type` on the given obj. It will be destroyed when the script is.
 * @template {keyof ComponentNameMap} T
 * @param {SceneObject} obj 
 * @param {T} type 
 * @returns {ComponentNameMap[T]} 
 */
DestructionHelper.prototype.createComponent = function(obj, type) {
    var comp = obj.createComponent(type);
    this._toDestroy.push(comp);
    return comp;
}

/**
 * Creates a SceneObject with the given parent. It will be destroyed when the script is.
 * @param {SceneObject} parent 
 * @returns {SceneObject}
 */
DestructionHelper.prototype.createSceneObject = function(parent) {
    var obj = global.scene.createSceneObject("");
    obj.setParent(parent);
    this._toDestroy.push(obj);
    return obj;
}

module.exports = DestructionHelper;
