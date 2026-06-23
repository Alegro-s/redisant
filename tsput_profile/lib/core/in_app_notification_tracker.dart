import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/lab_work.dart';
import '../../data/models/schedule.dart';

class InAppNotificationTracker {
  InAppNotificationTracker._();

  static const _scheduleKey = 'notify_schedule_fp';
  static const _labsKey = 'notify_labs_fp';

  static String scheduleFingerprint(List<Schedule> items) {
    final sorted = [...items]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return sorted
        .map((e) => '${e.id}|${e.startTime.toIso8601String()}|${e.subject}|${e.classroom}')
        .join(';');
  }

  static String labsFingerprint(List<LabWork> items) {
    final sorted = [...items]..sort((a, b) => a.id.compareTo(b.id));
    return sorted.map((e) => '${e.id}|${e.status}|${e.teacherComment}').join(';');
  }

  static Future<({bool scheduleChanged, bool labsChanged})> detectChanges({
    required List<Schedule> schedule,
    required List<LabWork> labs,
  }) async {
    final p = await SharedPreferences.getInstance();
    final prevSch = p.getString(_scheduleKey);
    final prevLabs = p.getString(_labsKey);
    final schFp = scheduleFingerprint(schedule);
    final labsFp = labsFingerprint(labs);

    final scheduleChanged = prevSch != null && prevSch.isNotEmpty && prevSch != schFp;
    final labsChanged = prevLabs != null && prevLabs.isNotEmpty && prevLabs != labsFp;

    await p.setString(_scheduleKey, schFp);
    await p.setString(_labsKey, labsFp);

    return (scheduleChanged: scheduleChanged, labsChanged: labsChanged);
  }
}
