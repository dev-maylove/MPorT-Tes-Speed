#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

# ============================================================
# GitHub Actions Cleanup PRO V2
# Flutter / Android APK / AAB
# ============================================================

KEEP_SUCCESS_RUNS_PER_WORKFLOW=3
KEEP_ARTIFACTS_PER_NAME=3

# true  = hanya preview, tidak menghapus
# false = mode penghapusan
DRY_RUN=false

MAX_RETRIES=5
RETRY_DELAY=3

# ============================================================
# CHECK DEPENDENCY
# ============================================================

command -v gh >/dev/null 2>&1 || {
    echo "ERROR: GitHub CLI belum terinstall."
    echo "Jalankan: pkg install gh"
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    echo "ERROR: jq belum terinstall."
    echo "Jalankan: pkg install jq"
    exit 1
}

if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: GitHub CLI belum login."
    echo "Jalankan: gh auth login"
    exit 1
fi

REPO="$(gh repo view --json nameWithOwner -q '.nameWithOwner')"

if [ -z "$REPO" ]; then
    echo "ERROR: Repository tidak ditemukan."
    exit 1
fi

# ============================================================
# TEMP DIRECTORY
# ============================================================

TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

RUNS_JSONL="$TMP_DIR/runs.jsonl"
RUNS_JSON="$TMP_DIR/runs.json"

KEEP_RUNS="$TMP_DIR/keep_runs.txt"
DELETE_RUNS="$TMP_DIR/delete_runs.txt"

ARTIFACTS_JSONL="$TMP_DIR/artifacts.jsonl"
ARTIFACTS_JSON="$TMP_DIR/artifacts.json"

KEEP_ARTIFACTS="$TMP_DIR/keep_artifacts.txt"
DELETE_ARTIFACTS="$TMP_DIR/delete_artifacts.txt"

# ============================================================
# API RETRY FUNCTION
# ============================================================

api_retry() {

    local ATTEMPT=1

    while [ "$ATTEMPT" -le "$MAX_RETRIES" ]
    do

        if gh api "$@"; then
            return 0
        fi

        echo
        echo "API gagal. Percobaan $ATTEMPT/$MAX_RETRIES"

        if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
            echo "Menunggu $RETRY_DELAY detik..."
            sleep "$RETRY_DELAY"
        fi

        ATTEMPT=$((ATTEMPT + 1))

    done

    echo
    echo "ERROR: API gagal setelah $MAX_RETRIES percobaan."
    return 1
}

# ============================================================
# HEADER
# ============================================================

echo
echo "=================================================="
echo " GITHUB ACTIONS CLEANUP PRO V2"
echo " Flutter / APK / AAB"
echo "=================================================="
echo

echo "Repository                    : $REPO"
echo "Success run per workflow      : $KEEP_SUCCESS_RUNS_PER_WORKFLOW"
echo "Artifact backup per nama      : $KEEP_ARTIFACTS_PER_NAME"

if [ "$DRY_RUN" = true ]; then
    echo "Mode                          : DRY RUN (AMAN)"
else
    echo "Mode                          : DELETE MODE"
fi

echo

# ============================================================
# GET ALL WORKFLOW RUNS
# ============================================================

echo "=================================================="
echo " MENGAMBIL SEMUA WORKFLOW RUN"
echo "=================================================="
echo

api_retry \
    --paginate \
    "repos/$REPO/actions/runs?per_page=100" \
    --jq '.workflow_runs[]' \
    > "$RUNS_JSONL"

if [ ! -s "$RUNS_JSONL" ]; then
    echo "Tidak ada workflow run."
    exit 0
fi

jq -s '.' "$RUNS_JSONL" > "$RUNS_JSON"

TOTAL_RUNS="$(jq 'length' "$RUNS_JSON")"

echo "Total Workflow Runs: $TOTAL_RUNS"
echo

# ============================================================
# KEEP SUCCESSFUL RUNS
# ============================================================

echo "=================================================="
echo " MENENTUKAN RUN YANG DIPERTAHANKAN"
echo "=================================================="
echo

# Simpan 3 SUCCESS terbaru per workflow.
# Jika sebuah workflow tidak memiliki SUCCESS,
# simpan 1 run terbaru sebagai cadangan.

jq \
    --argjson keep "$KEEP_SUCCESS_RUNS_PER_WORKFLOW" '

    group_by(.workflow_id)

    | map(

        .

        | sort_by(.created_at)

        | reverse

        | (
            map(select(.conclusion == "success"))
            | .[:$keep]
          )

      )

    | flatten

    | .[]

    | .id

' "$RUNS_JSON" > "$KEEP_RUNS"

# Fallback:
# Jika workflow tertentu tidak memiliki run success,
# simpan run terbaru workflow tersebut.

jq -r '
    group_by(.workflow_id)

    | .[]

    | (
        map(select(.conclusion == "success"))
        | length
      ) as $success_count

    | if $success_count == 0
      then
        sort_by(.created_at)
        | reverse
        | .[0]
        | .id
      else
        empty
      end

' "$RUNS_JSON" >> "$KEEP_RUNS"

sort -u "$KEEP_RUNS" -o "$KEEP_RUNS"

KEEP_RUN_COUNT="$(wc -l < "$KEEP_RUNS" | tr -d ' ')"

# ============================================================
# DETERMINE RUNS TO DELETE
# ============================================================

jq -r '.[].id' "$RUNS_JSON" |
while read -r RUN_ID
do

    if ! grep -qx "$RUN_ID" "$KEEP_RUNS"; then
        echo "$RUN_ID"
    fi

done > "$DELETE_RUNS"

DELETE_RUN_COUNT="$(wc -l < "$DELETE_RUNS" | tr -d ' ')"

# ============================================================
# SHOW KEPT RUNS
# ============================================================

echo "Run yang dipertahankan:"
echo

jq -r \
    --rawfile keep "$KEEP_RUNS" '

    ($keep | split("\n") | map(select(length > 0))) as $keep_ids

    | .[]

    | select(
        (.id | tostring) as $id
        | $keep_ids
        | index($id)
      )

    | "\(.name)"
      + "\n  Run ID  : \(.id)"
      + "\n  Status  : \(.conclusion // .status)"
      + "\n  Branch  : \(.head_branch)"
      + "\n  Date    : \(.created_at)"
      + "\n"

' "$RUNS_JSON"

# ============================================================
# GET ALL ARTIFACTS
# ============================================================

echo
echo "=================================================="
echo " MENGAMBIL SEMUA ARTIFACT"
echo "=================================================="
echo

api_retry \
    --paginate \
    "repos/$REPO/actions/artifacts?per_page=100" \
    --jq '.artifacts[]' \
    > "$ARTIFACTS_JSONL"

if [ -s "$ARTIFACTS_JSONL" ]; then
    jq -s '.' "$ARTIFACTS_JSONL" > "$ARTIFACTS_JSON"
else
    echo "[]" > "$ARTIFACTS_JSON"
fi

TOTAL_ARTIFACTS="$(jq 'length' "$ARTIFACTS_JSON")"

echo "Total Artifacts: $TOTAL_ARTIFACTS"
echo

# ============================================================
# KEEP ARTIFACTS FROM KEPT RUNS
# ============================================================

echo "=================================================="
echo " MENGANALISIS ARTIFACT"
echo "=================================================="
echo

# 1. Simpan artifact yang terkait dengan run yang dipertahankan.

jq -r \
    --rawfile keep "$KEEP_RUNS" '

    ($keep | split("\n") | map(select(length > 0))) as $keep_ids

    | .[]

    | select(
        (.workflow_run.id | tostring) as $run_id
        | $keep_ids
        | index($run_id)
      )

    | .id

' "$ARTIFACTS_JSON" \
> "$TMP_DIR/artifacts_from_kept_runs.txt"

# 2. Simpan N artifact terbaru untuk SETIAP nama artifact.

jq -r \
    --argjson keep "$KEEP_ARTIFACTS_PER_NAME" '

    group_by(.name)

    | .[]

    | sort_by(.created_at)

    | reverse

    | .[:$keep]

    | .[]

    | .id

' "$ARTIFACTS_JSON" \
> "$TMP_DIR/latest_artifacts_per_name.txt"

# Gabungkan kedua aturan.

cat \
    "$TMP_DIR/artifacts_from_kept_runs.txt" \
    "$TMP_DIR/latest_artifacts_per_name.txt" \
    2>/dev/null \
    | sort -u \
    > "$KEEP_ARTIFACTS"

KEEP_ARTIFACT_COUNT="$(wc -l < "$KEEP_ARTIFACTS" | tr -d ' ')"

# ============================================================
# DETERMINE ARTIFACTS TO DELETE
# ============================================================

jq -r '.[].id' "$ARTIFACTS_JSON" |
while read -r ARTIFACT_ID
do

    if ! grep -qx "$ARTIFACT_ID" "$KEEP_ARTIFACTS"; then
        echo "$ARTIFACT_ID"
    fi

done > "$DELETE_ARTIFACTS"

DELETE_ARTIFACT_COUNT="$(wc -l < "$DELETE_ARTIFACTS" | tr -d ' ')"

# ============================================================
# SHOW KEPT ARTIFACTS
# ============================================================

echo "Artifact yang dipertahankan:"
echo

jq -r \
    --rawfile keep "$KEEP_ARTIFACTS" '

    ($keep | split("\n") | map(select(length > 0))) as $keep_ids

    | .[]

    | select(
        (.id | tostring) as $id
        | $keep_ids
        | index($id)
      )

    | "\(.name)"
      + "\n  Artifact ID : \(.id)"
      + "\n  Run ID      : \(.workflow_run.id)"
      + "\n  Created     : \(.created_at)"
      + "\n"

' "$ARTIFACTS_JSON"

# ============================================================
# SUMMARY
# ============================================================

echo
echo "=================================================="
echo " RINGKASAN"
echo "=================================================="
echo

echo "Repository:"
echo "  $REPO"
echo

echo "Workflow Runs:"
echo "  Total              : $TOTAL_RUNS"
echo "  Dipertahankan      : $KEEP_RUN_COUNT"
echo "  Akan dihapus       : $DELETE_RUN_COUNT"
echo

echo "Artifacts:"
echo "  Total              : $TOTAL_ARTIFACTS"
echo "  Dipertahankan      : $KEEP_ARTIFACT_COUNT"
echo "  Akan dihapus       : $DELETE_ARTIFACT_COUNT"
echo

echo "=================================================="

# ============================================================
# DRY RUN
# ============================================================

if [ "$DRY_RUN" = true ]; then

    echo
    echo "MODE DRY RUN AKTIF"
    echo
    echo "Tidak ada Workflow Run atau Artifact yang dihapus."
    echo
    echo "Jika daftar di atas sudah benar:"
    echo
    echo "nano cleanup-flutter-builds-pro.sh"
    echo
    echo "Ubah:"
    echo
    echo "DRY_RUN=true"
    echo
    echo "Menjadi:"
    echo
    echo "DRY_RUN=false"
    echo
    echo "Kemudian jalankan kembali:"
    echo
    echo "./cleanup-flutter-builds-pro.sh"
    echo

    exit 0
fi

# ============================================================
# CONFIRMATION
# ============================================================

echo
echo "=================================================="
echo " PERINGATAN PENGHAPUSAN"
echo "=================================================="
echo

echo "Akan dihapus:"
echo
echo "  Workflow Runs : $DELETE_RUN_COUNT"
echo "  Artifacts     : $DELETE_ARTIFACT_COUNT"
echo

echo "Data yang dihapus tidak dapat dikembalikan."
echo
echo "Ketik persis:"
echo
echo "DELETE"
echo

read -r -p "Konfirmasi: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then

    echo
    echo "=================================================="
    echo " DIBATALKAN"
    echo "=================================================="
    echo
    echo "Tidak ada data yang dihapus."

    exit 0
fi

# ============================================================
# DELETE ARTIFACTS
# ============================================================

echo
echo "=================================================="
echo " MENGHAPUS ARTIFACT LAMA"
echo "=================================================="
echo

CURRENT=0

while read -r ARTIFACT_ID
do

    [ -z "$ARTIFACT_ID" ] && continue

    CURRENT=$((CURRENT + 1))

    echo "[$CURRENT/$DELETE_ARTIFACT_COUNT] Artifact: $ARTIFACT_ID"

    api_retry \
        --method DELETE \
        "repos/$REPO/actions/artifacts/$ARTIFACT_ID"

    sleep 1

done < "$DELETE_ARTIFACTS"

# ============================================================
# DELETE WORKFLOW RUNS
# ============================================================

echo
echo "=================================================="
echo " MENGHAPUS WORKFLOW RUN LAMA"
echo "=================================================="
echo

CURRENT=0

while read -r RUN_ID
do

    [ -z "$RUN_ID" ] && continue

    CURRENT=$((CURRENT + 1))

    echo "[$CURRENT/$DELETE_RUN_COUNT] Run: $RUN_ID"

    api_retry \
        --method DELETE \
        "repos/$REPO/actions/runs/$RUN_ID"

    sleep 1

done < "$DELETE_RUNS"

# ============================================================
# FINISHED
# ============================================================

echo
echo "=================================================="
echo " SELESAI"
echo "=================================================="
echo

echo "✓ Workflow Runs lama dibersihkan."
echo "✓ $KEEP_SUCCESS_RUNS_PER_WORKFLOW run SUCCESS terbaru per workflow dipertahankan."
echo "✓ Artifact dari run yang dipertahankan tetap aman."
echo "✓ $KEEP_ARTIFACTS_PER_NAME artifact terbaru per nama juga dipertahankan."
echo
