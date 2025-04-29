var defaultTransformer = MachineLearning.createTransformerBuilder()
    .setStretch(true)
    .setFillColor(new vec4(0.0, 0.0, 0.0, 1.0))
    .setVerticalAlignment(VerticalAlignment.Center)
    .setHorizontalAlignment(HorizontalAlignment.Center)
    .setFlipX(false)
    .setFlipY(false)
    .setRotation(TransformerRotation.None)
    .build();

var defaultTransformerNoStretch = MachineLearning.createTransformerBuilder()
    .setStretch(false)
    .setFillColor(new vec4(0.0, 0.0, 0.0, 1.0))
    .setVerticalAlignment(VerticalAlignment.Center)
    .setHorizontalAlignment(HorizontalAlignment.Center)
    .setFlipX(false)
    .setFlipY(false)
    .setRotation(TransformerRotation.None)
    .build();

var defaultSampler = MachineLearning.createSamplerBuilder()
    .setFilteringMode(FilteringMode.Bilinear)
    .setWrapUMode(WrapMode.ClampToBorder)
    .setWrapVMode(WrapMode.ClampToBorder)
    .setBorderColor(new vec4(0.0, 0.0, 0.0, 0.0))
    .setUseMipmaps(false)
    .build()

var modelsBuilding = [];

function buildModel(model, samplerInputs, inputsStretch, textureOutputs, verbose=false, backendPriority=[]) {
    if (verbose) {
        print("building model " + model.model.name);
    }

    var placeholders = [];
    samplerInputs = samplerInputs == undefined ? [] : samplerInputs;
    textureOutputs = textureOutputs == undefined ? [] : textureOutputs;

    // build inputs
    for (var i = 0; i < model.getInputs().length; ++i) {
        inputName = model.getInputs()[i].name;
        var input = MachineLearning.createInputBuilder()
            .setName(inputName)
            .setShape(model.getInputs()[i].shape)
            .setTransformer(inputsStretch[i] ? defaultTransformer : defaultTransformerNoStretch)
        if (samplerInputs.includes(inputName)) {
            input = input.setSampler(defaultSampler)
        }
        input = input.build();
        placeholders.push(input);
    }

    if (backendPriority.length > 0) {
        model.setBackendPriorityList(backendPriority);
    }

    // build outputs
    for (var i = 0; i < model.getOutputs().length; ++i) {
        outputName = model.getOutputs()[i].name;
        var output = MachineLearning.createOutputBuilder()
            .setName(outputName)
            .setShape(model.getOutputs()[i].shape)
        if ((model.getOutputs()[i].shape.z <= 4) && textureOutputs.includes(outputName))  {
            output = output.setOutputMode(MachineLearning.OutputMode.Texture)
        }
        output = output.build();
        placeholders.push(output);
    }

    // build model
    model.build(placeholders);
    modelsBuilding.push(model);
}


function linkDataLayout(mlcompOut, outputName, mlcompIn, inputName) {
    try {
        if (inputName == undefined) { inputName = outputName; }
        var internalDataLayout = mlcompOut.getOutput(outputName).internalDataLayout;
        if (internalDataLayout == undefined) { return }

        mlcompOut.getOutput(outputName).dataLayout = internalDataLayout;
        mlcompIn.getInput(inputName).dataLayout = internalDataLayout;
    } catch (e) {
        print("linkDataLayout failed: " + e + " " + mlcompOut.model.name + "::" + outputName + " -> " + mlcompIn.model.name + "::" + inputName);
    }
}

var _onLoadingFinishedCallback;

function onLoadingFinishedInternal() {
    var waitingForModels = false;
    modelsBuilding.forEach(function(model) {
        if (model.state != MachineLearning.ModelState.Idle) {
            waitingForModels = true;
            model.onLoadingFinished = onLoadingFinishedInternal;
        }
    })
    if (!waitingForModels) {
        modelsBuilding = [];
        _onLoadingFinishedCallback();
    }
}

Object.defineProperty(script, "onLoadingFinished", {
    get: function() {
        return _onLoadingFinishedCallback;
    },
    set: function(callback) {
        _onLoadingFinishedCallback = callback;
        onLoadingFinishedInternal();
    }
});

script.buildModel = buildModel;
script.linkDataLayout = linkDataLayout;
