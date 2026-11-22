#!/usr/bin/env bash
# Copies the debug binary and fuzz.py into the Tart VM `scuttle`, restarts the app there from that binary,
# runs the fuzzer over ssh and prints its output. Usage: scripts/vm-fuzz.sh <seed> <steps> [--switching]
set -uo pipefail
cd "$(dirname "$0")/.."

IP="${SCUTTLE_VM_IP:-$(tart ip scuttle)}"
SSH_OPTS=(-i ~/.ssh/id_rsa -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/tmp/scuttle-known-hosts)

ssh "${SSH_OPTS[@]}" "admin@$IP" 'pkill -f "[d]inky.app"; pkill -f "[d]inky[-a-z0-9]* app"; pkill -x TextEdit; pkill -x Safari; sleep 1'
scp -q "${SSH_OPTS[@]}" .build/debug/scuttle "admin@$IP:scuttle-fuzz"
scp -q "${SSH_OPTS[@]}" scripts/fuzz.py "admin@$IP:fuzz.py"
ssh "${SSH_OPTS[@]}" "admin@$IP" 'nohup ~/scuttle-fuzz app > /tmp/scuttle-fuzz.log 2>&1 < /dev/null & sleep 3'
ssh "${SSH_OPTS[@]}" "admin@$IP" "python3 -u ~/fuzz.py --seed $1 --steps $2 --scuttle ~/scuttle-fuzz ${3:-}"
status=$?
ssh "${SSH_OPTS[@]}" "admin@$IP" 'pkill -f "[d]inky-fuzz app"; echo "app log: /tmp/scuttle-fuzz.log in the guest"'
exit $status
