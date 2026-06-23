/// L24a — typed engine manifest release (size + changelog).
class NexusEngineReleaseInfo {
  final String version;
  final String? notes;
  final String? changelog;
  final int? sizeBytes;
  final Map<String, dynamic> artifacts;

  const NexusEngineReleaseInfo({
    required this.version,
    this.notes,
    this.changelog,
    this.sizeBytes,
    this.artifacts = const {},
  });

  factory NexusEngineReleaseInfo.fromJson(Map<String, dynamic> json) {
    int? size;
    final rawSize = json['sizeBytes'] ?? json['size_bytes'] ?? json['bytes'];
    if (rawSize is num) size = rawSize.toInt();
    final log = json['changelog']?.toString() ?? json['releaseNotes']?.toString();
    final arts = json['artifacts'];
    return NexusEngineReleaseInfo(
      version: json['version']?.toString() ?? '?',
      notes: json['notes']?.toString(),
      changelog: log,
      sizeBytes: size,
      artifacts: arts is Map ? Map<String, dynamic>.from(arts) : const {},
    );
  }

  String get sizeLabel {
    final b = sizeBytes;
    if (b == null || b <= 0) return '';
    if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1)} GB';
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    if (b >= 1 << 10) return '${(b / (1 << 10)).toStringAsFixed(0)} KB';
    return '$b B';
  }

  String get displaySubtitle {
    final parts = <String>[];
    if (sizeLabel.isNotEmpty) parts.add(sizeLabel);
    if (changelog != null && changelog!.trim().isNotEmpty) {
      parts.add(changelog!.trim().split('\n').first);
    } else if (notes != null && notes!.trim().isNotEmpty) {
      parts.add(notes!.trim());
    }
    return parts.join(' · ');
  }
}

class NexusEngineManifestSnapshot {
  final List<Map<String, dynamic>> releases;
  final String? recommendedVersion;
  final String? source;

  const NexusEngineManifestSnapshot({
    required this.releases,
    this.recommendedVersion,
    this.source,
  });

  List<NexusEngineReleaseInfo> get releaseEntries =>
      releases.map((r) => NexusEngineReleaseInfo.fromJson(r)).toList();
}
