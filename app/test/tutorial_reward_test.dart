// The tutorial's XP: once per account, as an XP-only receipt with a fixed
// id the server credits only once (see server/test/xp_economy_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/sync_queue_service.dart';

import 'helpers/screen_harness.dart';

void main() {
  setUp(() => usePrefs({'total_xp': 120}));

  test('the first finish adds the XP and queues one fixed receipt', () {
    final queue = SyncQueueService(signedOutAuth());
    expect(queue.recordTutorialReward(), SyncQueueService.tutorialRewardXp);
    expect(PrefsService.totalXp, 120 + SyncQueueService.tutorialRewardXp);

    final receipt = PrefsService.pendingSyncReceipts.single;
    expect(receipt.id, SyncQueueService.tutorialReceiptId);
    expect(receipt.xp, SyncQueueService.tutorialRewardXp);
    expect(receipt.isMatch, isFalse, reason: 'not a match: no stats');
    expect(receipt.toJson().containsKey('match'), isFalse);
  });

  test('a second finish on the same account adds nothing', () {
    final queue = SyncQueueService(signedOutAuth());
    queue.recordTutorialReward();
    expect(queue.recordTutorialReward(), 0);
    expect(PrefsService.totalXp, 120 + SyncQueueService.tutorialRewardXp);
    expect(PrefsService.pendingSyncReceipts, hasLength(1));
  });

  test('the claim survives an app restart', () async {
    SyncQueueService(signedOutAuth()).recordTutorialReward();
    await usePrefs({
      'total_xp': PrefsService.totalXp,
      'tutorial_xp_claimed_by': PrefsService.tutorialXpClaimedBy.toList(),
    });
    expect(SyncQueueService(signedOutAuth()).recordTutorialReward(), 0);
  });
}
