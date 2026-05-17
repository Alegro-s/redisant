class NexusEngineManifestSnapshot {
  final List<Map<String, dynamic>> releases;
  final String? recommendedVersion;
  final String? source;

  const NexusEngineManifestSnapshot({
    required this.releases,
    this.recommendedVersion,
    this.source,
  });
}
