#!/usr/bin/env bash
set -euo pipefail
mkdir -p ci-logs
# Start firestore emulator in background; requires firebase-tools installed and configured
firebase emulators:start --only firestore --project targometro > ci-logs/emulator.log 2>&1 &
EMULATOR_PID=$!
# wait for emulator readiness
for i in {1..60}; do
  if grep -q "All emulators ready" ci-logs/emulator.log; then
    echo "Emulator ready"
    break
  fi
  sleep 1
done
if ! grep -q "All emulators ready" ci-logs/emulator.log; then
  echo "Emulator failed to start; last 200 lines:"
  tail -n 200 ci-logs/emulator.log || true
  kill $EMULATOR_PID || true
  exit 1
fi
# Run the integration test
flutter test integration_test/e2e_sync_test.dart -r expanded 2>&1 | tee ci-logs/e2e_test.log
TEST_RC=${PIPESTATUS[0]}
# Stop emulator
kill $EMULATOR_PID || true
exit $TEST_RC
