import 'package:dio/dio.dart';

import 'nexus_engine_manifest.dart';

export 'nexus_engine_manifest.dart';

Future<String?> ensureEngineBinary(Dio dio, {String? preferredVersion}) async => null;

Future<String?> getLastCachedEngineLibraryPath() async => null;

Future<String?> getInstalledEngineVersionLabel() async => null;

Future<String?> fetchRecommendedEngineVersion(Dio dio) async => null;

Future<NexusEngineManifestSnapshot?> fetchEngineManifestSnapshot(Dio dio) async => null;

bool engineReleaseSupportsCurrentHost(Map<String, dynamic> release) => false;
