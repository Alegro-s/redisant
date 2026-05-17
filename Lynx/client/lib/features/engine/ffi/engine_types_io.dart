import 'dart:ffi';

typedef SceneHandle = Pointer<Void>;

final SceneHandle kSceneNull = nullptr;

bool sceneIsNull(SceneHandle h) => h == nullptr;
