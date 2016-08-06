
class SB_IModelLoaderLib {
    unsigned libStatus () = 0;
    void teardown () = 0;
    bool loadFile (const char* path, SbModelLoadDelegate*) = 0;
};
enum { 
    SB_LIB_NOT_INITIALIZED = 0,
    SB_LIB_INITIALIZED = 1,
    SB_LIB_INIT_ERROR  = 2,
    SB_LIB_RUNTIME_ERROR = 3
};
class SbCLibDelegate {
    void reportError (const char* error, ...) = 0;
    void logMessage  (const char* msg, ...)   = 0;
    const char* localPath ();
};
class SbModelLoadDelegate {
    void reportError (const char* error, ...) = 0;
    void logMessage  (const char* msg, ...) = 0;
};




SB_IModelLoaderLib sbCreateFbxLoader (SbCLibDelegate* gsb) {
    return new FBXLoaderLib(gsb);
}

class FBXLoaderLib : SB_IModelLoaderLib {
    SbCLibDelegate* gsb;
    unsigned libStatus = 0;
    FbxManager* sdk;

    FBXLoaderLib ( SbCLibDelegate gsb ) :
        gsb( gsb ), 
        libStatus( 0 ),
        sdk( null )
    {
        sdk = FbxManager::Create();
        if (!sdk) {
            gsb->reportError("Unable to create FBX Manager (critical)");
            libStatus = SB_LIB_INIT_ERROR;
            return;
        } else {
            int sdk_major, sdk_minor, sdk_rev;
            FbxManager::GetFileFormatVersion(sdk_major, sdk_minor, sdk_rev);
            gsb->logMessage("Loaded FBX SDK v%d.%d.%d", sdk_major, sdk_minor, sdk_rev);
        }
        FbxIOSettings* ios = FbxIOSettings::Create(sdk, IOSROOT);
        sdk->SetIOSettings(ios);
    }
    void teardown () {
        if (sdk) {
            sdk->Destroy();
            sdk = nullptr;
        }
    }
    bool loadFile (const char* file, SbModelLoadDelegate* dg) {

        // Try loading file
        auto importer = FbxImporter::Create(sdk, "");
        bool importOk = importer->Initialize(file, -1, sdk->GetIOSettings());
        if (!importOK) {
            if (importer->GetStatus().GetCode() == FbxStatus::eInvalidFileVersion) {
                int sdk_major, sdk_minor, sdk_rev;
                int major, minor, rev;
                FbxManager::GetFileFormatVersion(sdk_major, sdk_minor, sdk_rev);
                importer->GetFileVersion(major, minor, rev);

                dg->reportError(
                    "Import Failed: Invalid file version.\n\tFBX SDK v%d.%d.%d\n\tFile v%d.%d.%d",
                    sdk_major, sdk_minor, sdk_rev, major, minor, rev);
                return;
            } else {
                auto err = importer->GetStatus().GetErrorString().Buffer();
                dg->reportError("Import Failed: %s", err);
                return;
            }
        } else {
            int major, minor, rev;
            importer->logMessage("Loaded file '%s'. File version %d.%d.%d",
                file, major, minor, rev);
        }

        // Import file contents into an fbx scene
        auto scene = FbxScene::Create(sdk, "");
        if (!scene) {
            dg->reportError("Could not create scene object! (critical)");
            return;
        }
        if (!importer->Import(scene)) {
            dg->reportError("Could not load into scene! (critical)");
            return;
        }
        importer->Destroy();

        // And traverse the scene...
        FbxLoader doLoad (dg, scene);

        scene->Destroy();
    }
};

class FbxLoader {
    SbModelLoadDelegate* dg;

    this (SbModelLoadDelegate* dg, FbxScene* scene) : dg(dg) 
    {
        assert(dg && scene);

        auto root = scene->GetRootNode();
        if (!root) {
            dg->reportError("Null scene root node!");
            return;
        }
        traverseNodes( scene->GetRootNode() );
    }

    void traverseNodes (FbxNode* node) {
        if (node->GetAttribute() == nullptr) {
            dg->logMessage("ERROR (non-critical): node has null attribute!");
            return;
        }
        auto attribType = node->GetNodeAttribute()->GetAttributeType();
        switch (attribType) {
            default: break;
            case FbxNodeAttribute::eMarker: break;
            case FbxNodeAttribute::eSkeleton: break;
            case FbxNodeAttribute::eMesh:
                traverseMesh(node);
                break;
            case FbxNodeAttribute::eNurbs:
                dg->logMessage("Unsupported fbx node (NURBS); skipping");
                break;
            case FbxNodeAttribute::ePatch:
                dg->logMessage("Unsupported fbx node: (patch); skipping");
                break;
            case FbxNodeAttribute::eCamera:
                traverseCamera(node);
                break;
            case FbxNodeAttribute::eLight:
                traverseLight(node);
                break;
            case FbxNodeAttribute::eLODGroup:
                traverseLodGroup(node);
                break;
        }
        // handle user properties, target, pivots + limits, transform propogation,
        // geometric transform...?

        for (auto i = 0; i < node->GetChildCount(); ++i) {
            traverseNodes(node->GetChild(i));
        }
    }
    void sendNodeTransform (FbxNode* node) {
        FbxVector4 pos = node->GetGeometricTranslation(FbxNode::eSourcePivot);
        FbxVector4 rot = node->GetGeometricRotation(FbxNode::eSourcePivot);
        FbxVector4 scale = node->GetGeometricScaling(FbxNode::eSourcePivot);

        dg->setTransform( &pos[0], &rot[0], &scale[0] );
    }
    void traverseCamera (FbxNode* node) {
        FbxCamera*  camera   = (FbxCamera*)node->GetNodeAttribute();
        const char* name     = node->GetName();
        // FbxNode*    target   = node->GetTarget();
        // FbxNode*    upTarget = node->GetTargetUp();

        // Get look direction + up vector (orientation)
        FbxVector3 targetPos = camera->InterestPosition.Get();
        FbxVector3 upDir     = camera->UpVector.Get();
        double     roll      = camera->Roll.Get();

        // Transform info _should_ be geometric stuff above, right...?

        // projection types: 0 => perspective, 1 => orthogonal
        int projectionType = camera->ProjectionType.Get();

        // Send to gsb...
    }
    void traverseLight (FbxNode* node) {
        FbxLight* light = (FbxLight*) node->GetNodeAttribute();
        const char* name = node->GetName();

        // light types: 0 => point, 1 => directional, 2 => spot
        int  lightType = light->LightType.Get();
        bool castLight = light->CastLight.Get(); // dunno what this is...?

        // lights can be more complex (they have an optional file name / texture?)
        // (light.FileName.Get()), but we'll ignore this...

        // And light params...
        FbxDouble3 color      = light->Color.Get();
        double     intensity  = light->Intensity.Get();
        double     outerAngle = light->OuterAngle.Get();
        double     fog        = light->Fog.Get();

        // Send to gsb...
    }
    void traverseMesh (FbxNode* node) {
        
    }
};
