#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/vivobody"
TEST_DIR="$ROOT_DIR/vivobodyTests"

failures=0

# --- Rule 1: ViewModels must live in Features/*/ViewModels/ ---
echo "Checking ViewModel file placement..."
while IFS= read -r viewmodel; do
  dir="$(basename "$(dirname "$viewmodel")")"
  if [[ "$dir" != "ViewModels" ]]; then
    echo "error: ViewModel not in ViewModels/ directory: ${viewmodel#"$ROOT_DIR"/}"
    failures=1
  fi
done < <(find "$APP_DIR/Features" -name '*ViewModel.swift' 2>/dev/null | sort)

# --- Rule 2: Every ViewModel must have a matching test file ---
echo "Checking ViewModel test coverage..."
while IFS= read -r viewmodel; do
  name="$(basename "$viewmodel" .swift)"
  feature="$(basename "$(dirname "$(dirname "$viewmodel")")")"
  expected_test="$TEST_DIR/Features/$feature/${name}Tests.swift"

  if [[ ! -f "$expected_test" ]]; then
    echo "error: Missing test for $name"
    echo "  expected: ${expected_test#"$ROOT_DIR"/}"
    failures=1
  fi
done < <(find "$APP_DIR/Features" -path '*/ViewModels/*ViewModel.swift' 2>/dev/null | sort)

# --- Rule 3: No direct persistence mutations in feature views ---
# @Query and @Environment(\.modelContext) are fine (Apple-blessed patterns).
# What we prevent is views calling insert/delete/save/fetch directly --
# that logic belongs in a ViewModel.
echo "Checking for persistence mutations in feature views..."
while IFS= read -r viewfile; do
  relative="${viewfile#"$APP_DIR"/}"

  if grep -qE 'modelContext\.(insert|delete|fetch|save)\(' "$viewfile"; then
    echo "error: Direct modelContext mutation in feature view: $relative"
    echo "  Move insert/delete/fetch/save calls to a ViewModel."
    failures=1
  fi
done < <(find "$APP_DIR/Features" -path '*/Views/*.swift' 2>/dev/null | sort)

# --- Rule 4: No cross-feature references (filename-based index) ---
# A feature folder should only reference types from its own Views/ViewModels
# or Core/. Allowed cross-feature dependencies are listed below.
# Index is built from filenames in Views/ and ViewModels/ (the public surfaces).
echo "Checking cross-feature boundaries..."

ALLOWED_CROSS_FEATURE=(
  # WorkoutsHistory embeds the templates tab
  "Features/WorkoutsHistory/.*:WorkoutTemplatesView"
  # ActiveWorkout shows the completion screen
  "Features/ActiveWorkout/.*:WorkoutCompleteView"
  # ExerciseLibrary navigates to ExerciseDetail
  "Features/ExerciseLibrary/.*:ExerciseDetailView"
  # ExerciseDetail preview uses ExerciseLibrary sample data
  "Features/ExerciseDetail/.*:ExerciseLibraryView"
  # WorkoutLog presents ActiveWorkout
  "Features/WorkoutLog/.*:ActiveWorkoutView"
)

# Build index: "typename owning_feature" from View/ViewModel filenames (one pass)
CROSS_INDEX=""
while IFS= read -r f; do
  typename="$(basename "$f" .swift)"
  rel="${f#"$APP_DIR"/Features/}"
  feature="${rel%%/*}"
  CROSS_INDEX+="${typename} ${feature}"$'\n'
done < <(find "$APP_DIR/Features" \( -path '*/Views/*.swift' -o -path '*/ViewModels/*.swift' \) 2>/dev/null)

# For each source file, check for foreign type references
while IFS= read -r srcfile; do
  relative="${srcfile#"$APP_DIR"/}"
  src_feature="$(echo "$relative" | cut -d/ -f2)"

  while IFS=' ' read -r typename owner; do
    [[ -z "$typename" ]] && continue
    [[ "$owner" == "$src_feature" ]] && continue

    if grep -qw "$typename" "$srcfile" 2>/dev/null; then
      allowed=false
      for pattern in "${ALLOWED_CROSS_FEATURE[@]}"; do
        pat_file="${pattern%%:*}"
        pat_type="${pattern##*:}"
        if [[ "$relative" =~ $pat_file ]] && [[ "$typename" == "$pat_type" ]]; then
          allowed=true
          break
        fi
      done
      if ! $allowed; then
        echo "error: Cross-feature reference in $relative"
        echo "  Uses $typename from Features/$owner (move to Core/ or allowed list)."
        failures=1
      fi
    fi
  done <<< "$CROSS_INDEX"
done < <(find "$APP_DIR/Features" -name '*.swift' 2>/dev/null | sort)

# --- Rule 5: Core/ never imports Features/ types ---
echo "Checking Core/ does not reference Features/..."
# Collect all type names defined in Features/
FEATURE_TYPES=()
while IFS= read -r feat_file; do
  while IFS= read -r typename; do
    FEATURE_TYPES+=("$typename")
  done < <(grep -oE '(struct|class|enum)\s+[A-Z][A-Za-z0-9]+' "$feat_file" 2>/dev/null | awk '{print $2}')
done < <(find "$APP_DIR/Features" -name '*.swift' 2>/dev/null)

while IFS= read -r corefile; do
  relative="${corefile#"$APP_DIR"/}"
  for typename in "${FEATURE_TYPES[@]}"; do
    if grep -qE "\b${typename}\b" "$corefile" 2>/dev/null; then
      echo "error: Core file references Features type: $relative uses $typename"
      echo "  Core/ must not depend on Features/."
      failures=1
      break
    fi
  done
done < <(find "$APP_DIR/Core" -name '*.swift' 2>/dev/null | sort)

# --- Rule 6: Naming conventions for Views/ and ViewModels/ ---
# Files in Views/ must end with a recognized UI-pattern suffix.
# Non-view files (data helpers, extensions) belong in Helpers/.
# Files in ViewModels/ must end with ViewModel.swift.
echo "Checking naming conventions..."

VIEW_SUFFIXES="View|Row|Card|Section|Sections|Grid|Calendar|Chart|Timeline|List|Bar|Picker|Column|Header|Footer"

while IFS= read -r viewfile; do
  base="$(basename "$viewfile" .swift)"
  if ! echo "$base" | grep -qE "(${VIEW_SUFFIXES})$"; then
    echo "error: File in Views/ has non-view name: ${viewfile#"$APP_DIR"/}"
    echo "  Expected suffix: View, Row, Card, Section, List, etc. Move non-views to Helpers/."
    failures=1
  fi
done < <(find "$APP_DIR/Features" -path '*/Views/*.swift' 2>/dev/null | sort)

while IFS= read -r vmfile; do
  base="$(basename "$vmfile" .swift)"
  if ! echo "$base" | grep -qE "ViewModel$"; then
    echo "error: File in ViewModels/ does not end with ViewModel: ${vmfile#"$APP_DIR"/}"
    failures=1
  fi
done < <(find "$APP_DIR/Features" -path '*/ViewModels/*.swift' 2>/dev/null | sort)

# --- Rule 7: Every view file must contain a #Preview ---
# Agents must preserve and create previews when editing SwiftUI views.
# Extension-only files (no struct ... : View) are excluded -- the parent's preview covers them.
echo "Checking #Preview presence in view files..."
while IFS= read -r viewfile; do
  relative="${viewfile#"$APP_DIR"/}"

  # Skip files that don't define their own View struct
  if ! grep -qE '^struct [A-Za-z]+.*: View' "$viewfile"; then
    continue
  fi

  if ! grep -q '#Preview' "$viewfile"; then
    echo "error: Missing #Preview in view file: $relative"
    failures=1
  fi
done < <(find "$APP_DIR/Features" -path '*/Views/*.swift' 2>/dev/null | sort)

if [[ $failures -eq 0 ]]; then
  echo "Architecture checks passed."
fi

exit $failures
