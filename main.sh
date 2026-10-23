#!/usr/bin/env bash
# arte10 main — standalone modernization of the original painting/pixel-sort pipeline
# with cpu1, cpu2, and cpu1eu (Euclidean -> polar) post-processing.
# Requires Bash 3.2+, ImageMagick (7 preferred, 6 supported), and G'MIC.
# No GNU Parallel, GIMP, or pre-created s1..s38 directories required.
#
#   bash main.sh                         # s/ -> s25/, long edge 2000px
#   bash main.sh -i photos -o results -s 3000 -j 2
#   bash main.sh -s 2000,3000 -k           # two sizes; keep intermediate images
#   bash main.sh --check                  # check tools and actual filter calls
#
# Originals are read only. Each input/size produces 21 PNGs:
#   photo.png, photom5{a,b,c,d,h}.png,
#   photom5{a,b,c,d,h}cpu1.png, photom5{a,b,c,d,h}cpu2.png,
#   photom5{a,b,c,d,h}cpu1eu.png
# Multiple sizes add a final size tag (_2000, _3k, ...).
# Finger Paint uses randomness; identical settings need not yield identical pixels.

set -euo pipefail
shopt -s nullglob

DEFAULT_SIZE=2000
FPAINT=(-gtutor_fpaint '0.5,0.5,0,0,45,0.5,0.5,0.5,0')
ABSTRACT_FLOOD=(-fx_AbstractFlood '1,10,7,2,0,10,5,3,255,255,255,255,0,300,10,90,0.7,0,0,0')
UNSHARP=(-fx_unsharp '1,1.25,10,2,0,1,1,1,0,0,0,50,50')
BLOOM=(-fx_blur_bloom '1,2,3,2,0,0,0,0,7,0')
POSTER_EDGES=(-fx_poster_edges '20,60,5,0,10,0,0,0')
POLAR=(-fx_euclidean2polar '50,50,1,1,1')
VARIANTS=(m5a m5b m5c m5d m5h)
SUFFIXES=("" m5a m5b m5c m5d m5h
  m5acpu1 m5bcpu1 m5ccpu1 m5dcpu1 m5hcpu1
  m5acpu2 m5bcpu2 m5ccpu2 m5dcpu2 m5hcpu2
  m5acpu1eu m5bcpu1eu m5ccpu1eu m5dcpu1eu m5hcpu1eu)
PER_IMAGE=${#SUFFIXES[@]}

# W3C Soft Light for opaque RGB; used only if the native operator fails a probe.
SOFTLIGHT_FX='bot=u; top=v; top <= 0.5 ? bot-(1-2*top)*bot*(1-bot) : bot+(2*top-1)*((bot <= 0.25 ? ((16*bot-12)*bot+4)*bot : sqrt(bot))-bot)'
SOFTLIGHT_MODE=${ARTE10_SOFTLIGHT_MODE:-native}
TAG='[준비]'
STAGE='시작'
ACTIVE_COMMAND=''
RUN_DIR=''
LOCK_DIR=''
OWN_LOCK=0
KEEP=0
PIDS=()

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '오류: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
사용법: bash main.sh [옵션]

기존 페인팅/픽셀 정렬 5종과 cpu1/cpu2/cpu1eu(극좌표) 후처리를 한 파일로 실행합니다.
사진 한 장 × 크기 하나당 PNG ${PER_IMAGE}장을 만듭니다. 원본은 변경하지 않습니다.

  -i DIR       입력 폴더 (기본: main.sh 옆의 s/)
  -o DIR       결과 폴더 (기본: main.sh 옆의 s25/)
  -s PX        긴 변 크기 (기본: ${DEFAULT_SIZE}). 작은 이미지도 확대합니다.
               여러 크기: -s 2000,3000 / 원본 해상도: -s 0
               크기를 여러 개 주면 _2000, _3k, _original 등을 붙입니다.
  -j N         동시에 처리할 사진/크기 수 (기본: CPU·메모리 기준, 최대 4)
  -k           중간 이미지를 결과 폴더의 _work/run.*/ 에 보관
  -c           시작 전 이번 실행이 생성할 결과 파일만 삭제
               입력/다른 결과/하위 폴더는 삭제하지 않습니다.
  --check      입력 없이 도구와 실제 G'MIC 필터 호출 검사
  -h, --help   도움말

예:
  bash main.sh
  bash main.sh -i "내 사진" -o "변환 결과" -s 3000 -j 2
  bash main.sh -s 2000,3000 -k

필요 도구(macOS Homebrew): brew install imagemagick gmic
필터가 없으면: gmic up

입력은 폴더 바로 아래의 JPG/JPEG/PNG/TIF/TIFF/HEIC/HEIF/WEBP/BMP/AVIF/JXL.
실제 읽기 지원은 ImageMagick 빌드에 따릅니다. 여러 프레임은 첫 장만 사용.
투명 이미지는 흰 배경으로 합칩니다. 출력 이름의 공백은 _로 바꿉니다.
같은 이름의 기존 결과는 완성된 파일로 교체합니다. -c는 보통 불필요합니다.
효과는 픽셀 크기에 영향을 받습니다. 원래 느낌의 기준은 ${DEFAULT_SIZE}px입니다.
EOF
}

select_tools() {
  if command -v magick >/dev/null 2>&1; then
    IM_BIN=$(command -v magick)
  elif command -v convert >/dev/null 2>&1; then
    IM_BIN=$(command -v convert)
  else
    die 'ImageMagick이 없습니다. macOS: brew install imagemagick'
  fi
  command -v gmic >/dev/null 2>&1 || die "G'MIC CLI가 없습니다. macOS: brew install gmic"
  GMIC_BIN=$(command -v gmic)
  "$IM_BIN" -version >/dev/null 2>&1 || die 'ImageMagick을 실행할 수 없습니다.'
}

# Track the command so Ctrl-C/TERM can stop the image processor as well.
run() {
  local status=0
  "$@" &
  ACTIVE_COMMAND=$!
  wait "$ACTIVE_COMMAND" || status=$?
  ACTIVE_COMMAND=''
  if ((status != 0)); then
    printf '%s [%s] 실패 (종료 %s):' "$TAG" "$STAGE" "$status" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return "$status"
  fi
}

im() { run "$IM_BIN" -quiet "$@"; }
gm() {
  local input=$1 output=$2
  shift 2
  run "$GMIC_BIN" -v -1 "$input" "$@" -o "$output"
}

# blend <bottom> <top> <mode> <output>; layer order is part of the original look.
blend() {
  if [[ $3 == softlight && $SOFTLIGHT_MODE == formula ]]; then
    im "$1" "$2" -channel RGB -fx "$SOFTLIGHT_FX" +channel -alpha off "$4"
  else
    im "$1" "$2" -alpha off -channel RGB -compose "$3" -composite +channel "$4"
  fi
}

process() {
  local variant
  STAGE='페인팅과 공통 합성'
  gm base.png paint1.png "${FPAINT[@]}"
  blend paint1.png base.png softlight soft1.png
  gm soft1.png flood.png "${ABSTRACT_FLOOD[@]}"
  gm flood.png sharp.png "${UNSHARP[@]}"
  gm sharp.png paint2.png "${FPAINT[@]}"
  blend paint2.png sharp.png darken dark.png
  im dark.png -flop mirror.png
  blend mirror.png dark.png pinlight seed.png

  STAGE='픽셀 정렬 5종'
  gm seed.png m5b.png -fx_pixelsort 1,2,0,1,0,100,0,0,0
  gm m5b.png m5c.png -fx_pixelsort 1,3,2,1,0,100,0,0,0
  gm m5c.png m5d.png -fx_pixelsort 0,2,2,1,0,100,0,0,0
  gm m5c.png m5a.png -fx_pixelsort 1,3,0,1,0,100,0,0,0
  gm seed.png m5h.png -fx_pixelsort 1,3,2,1,0,100,0,0,0

  for variant in "${VARIANTS[@]}"; do
    STAGE="$variant 채도·블룸·후처리"
    im "$variant.png" -modulate 100,250,100 "$variant-sat.png"
    gm "$variant-sat.png" "$variant-bloom.png" "${BLOOM[@]}"
    # Preserve this RGB blend: the old -channel A does not make it a no-op on IM6.
    blend "$variant-bloom.png" "$variant.png" softlight "$variant-soft.png"
    gm "$variant-soft.png" "${variant}cpu2.png" "${POSTER_EDGES[@]}"
    gm "$variant-soft.png" "${variant}cpu1.png" "${ABSTRACT_FLOOD[@]}"
    gm "${variant}cpu1.png" "${variant}cpu1eu.png" "${POLAR[@]}"
  done
}

stop_command() {
  if [[ -n $ACTIVE_COMMAND ]]; then
    kill -TERM "$ACTIVE_COMMAND" 2>/dev/null || true
    wait "$ACTIVE_COMMAND" 2>/dev/null || true
  fi
}

cleanup() {
  local status=$? pid
  trap - EXIT INT TERM HUP
  stop_command
  for pid in "${PIDS[@]-}"; do
    [[ -n $pid ]] || continue
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "${PIDS[@]-}"; do
    [[ -n $pid ]] || continue
    wait "$pid" 2>/dev/null || true
  done
  if [[ -n $RUN_DIR && -d $RUN_DIR && $KEEP == 0 ]]; then
    rm -rf "$RUN_DIR"
  fi
  if ((OWN_LOCK)); then
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
  exit "$status"
}

process_one() {
  local index=$1 total=$2 src=$3 size=$4 stem=$5 tag=$6
  local work suffix dest ext t0=$SECONDS
  [[ -n ${ARTE10_RUN_DIR:-} && -d $ARTE10_RUN_DIR && -d ${ARTE10_OUT:-} ]] ||
    die '내부 작업 인수가 올바르지 않습니다.'
  TAG="[$index/$total] $stem$tag"
  work=$(mktemp -d "$ARTE10_RUN_DIR/job.${index}.XXXXXX")
  trap stop_command EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  select_tools
  cd "$work"
  printf '%s\n' "$src" > source.txt
  log "$TAG 시작"

  STAGE='입력 복사·방향·크기 정리'
  ext=${src##*.}
  # Use a controlled name: IM/G'MIC interpret []/%/commas in image arguments.
  run cp "$src" "input.$ext"
  local args=(-auto-orient -background white -alpha remove -alpha off -colorspace sRGB)
  ((size == 0)) || args+=(-resize "${size}x${size}")
  im "input.${ext}[0]" "${args[@]}" -type TrueColor -depth 8 base.png
  rm -f "input.$ext"

  process

  STAGE='완성 파일 저장'
  mkdir publish
  # Finish and stage the entire photo before publishing. Each rename is atomic;
  # the set of renames is not a filesystem-wide transaction.
  for suffix in "${SUFFIXES[@]}"; do
    [[ -s ${suffix:-base}.png ]] || die "$TAG 결과가 없습니다: ${suffix:-base}.png"
    run cp "${suffix:-base}.png" "publish/$stem$suffix$tag.png"
  done
  for suffix in "${SUFFIXES[@]}"; do
    dest=$ARTE10_OUT/$stem$suffix$tag.png
    [[ ! -L $dest && ( ! -e $dest || -f $dest ) ]] || die "저장할 수 없는 경로: $dest"
    run mv -f "publish/$stem$suffix$tag.png" "$dest"
  done
  rmdir publish
  : > "$ARTE10_RUN_DIR/ok.$index"
  log "$TAG 완료: ${PER_IMAGE}장 ($((SECONDS - t0))초)"
  cd "$ARTE10_RUN_DIR"
  [[ ${ARTE10_KEEP:-0} == 1 ]] || rm -rf "$work"
}

preflight() {
  local dir=$1 error
  mkdir -p "$dir"
  STAGE='필터 호환성 검사'
  # Exercise the actual parameters, not unrelated sketch/watercolor filters.
  if ! run "$GMIC_BIN" -v -1 '64,64,1,3,255*(x+y+c)/(w+h+2)' \
    "${FPAINT[@]}" "${ABSTRACT_FLOOD[@]}" "${UNSHARP[@]}" \
    -fx_pixelsort 1,2,0,1,0,100,0,0,0 \
    -fx_pixelsort 1,3,2,1,0,100,0,0,0 \
    -fx_pixelsort 0,2,2,1,0,100,0,0,0 \
    -fx_pixelsort 1,3,0,1,0,100,0,0,0 \
    "${BLOOM[@]}" "${POSTER_EDGES[@]}" "${POLAR[@]}" -rm >"$dir/gmic.log" 2>&1; then
    cat "$dir/gmic.log" >&2
    die "G'MIC 필터 검사가 실패했습니다. 'gmic up' 후 다시 실행하세요. 계속 실패하면 위 오류를 확인하세요."
  fi

  STAGE='Soft Light 합성 검사'
  im -size 16x16 xc:black -colorspace sRGB -type TrueColor -fx 'i/15' "$dir/bottom.png"
  im -size 16x16 xc:black -colorspace sRGB -type TrueColor -fx 'j/15' "$dir/top.png"
  im "$dir/bottom.png" "$dir/top.png" -alpha off -channel RGB \
    -compose softlight -composite +channel "$dir/native.png"
  im "$dir/bottom.png" "$dir/top.png" -channel RGB \
    -fx "$SOFTLIGHT_FX" +channel -alpha off "$dir/formula.png"
  error=$("$IM_BIN" -quiet "$dir/native.png" "$dir/formula.png" -alpha off \
    -compose difference -composite -format '%[fx:maxima]' info:)
  SOFTLIGHT_MODE=native
  if ! awk -v error="$error" 'BEGIN { exit !(error ~ /^[0-9.eE+-]+$/ && error < 0.0002) }'; then
    SOFTLIGHT_MODE=formula
    log '이 ImageMagick에서는 Soft Light를 표준 수식으로 계산합니다.'
  fi
  export ARTE10_SOFTLIGHT_MODE=$SOFTLIGHT_MODE
}

cpu_count() {
  local n
  n=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || printf 1)
  [[ $n =~ ^[1-9][0-9]*$ ]] || n=1
  printf '%s\n' "$n"
}

memory_mb() {
  local memory=2048 limit used available
  if [[ -r /proc/meminfo ]]; then
    memory=$(awk '/^MemAvailable:/ { print int($2/1024); found=1; exit }
      /^MemTotal:/ { total=int($2/1024) } END { if (!found) print total }' /proc/meminfo)
    # Honor cgroup v2 memory headroom where available (e.g. containers).
    if [[ -r /sys/fs/cgroup/memory.max && -r /sys/fs/cgroup/memory.current ]]; then
      read -r limit < /sys/fs/cgroup/memory.max || true
      read -r used < /sys/fs/cgroup/memory.current || true
      if [[ ${limit:-} =~ ^[0-9]+$ && ${used:-} =~ ^[0-9]+$ ]]; then
        available=$(((limit - used) / 1024 / 1024))
        ((available >= memory)) || memory=$available
      fi
    fi
  elif command -v sysctl >/dev/null 2>&1; then
    memory=$(sysctl -n hw.memsize 2>/dev/null || printf 2147483648)
    memory=$((memory / 1024 / 1024))
  fi
  [[ $memory =~ ^[1-9][0-9]*$ ]] || memory=512
  printf '%s\n' "$memory"
}

size_tag() {
  if (($2 == 1)); then printf ''; return; fi
  case $1 in
    0) printf '_original' ;;
    3000) printf '_3k' ;;
    *) printf '_%s' "$1" ;;
  esac
}

main() {
  if [[ ${1:-} == --worker ]]; then
    shift
    (($# == 6)) || die '내부 작업 인수 개수가 잘못되었습니다.'
    process_one "$@"
    return
  fi

  local here self input output size_spec=$DEFAULT_SIZE jobs='' clean=0 check=0 opt
  local size_pattern='^(0|[1-9][0-9]*)(,(0|[1-9][0-9]*))*$'
  local file base size tag suffix dest source_file cpu memory max=0 original=0
  local estimate total index=0 failed=0 finished=0 threads pid t0=$SECONDS
  local inputs=() sizes=()
  here=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
  self=$here/$(basename "${BASH_SOURCE[0]}")
  input=$here/s
  output=$here/s25

  # Keep help usable even when no image tools are installed.
  case ${1:-} in
    --help) usage; return ;;
    --check) check=1; shift ;;
  esac
  OPTIND=1
  while getopts ':i:o:s:j:ckh' opt; do
    case $opt in
      i) input=$OPTARG ;;
      o) output=$OPTARG ;;
      s) size_spec=$OPTARG ;;
      j) jobs=$OPTARG ;;
      c) clean=1 ;;
      k) KEEP=1 ;;
      h) usage; return ;;
      :) die "-$OPTARG 옵션에 값이 필요합니다." ;;
      \?) die "알 수 없는 옵션: -$OPTARG (bash main.sh -h)" ;;
    esac
  done
  shift $((OPTIND - 1))
  (($# == 0)) || die "예상하지 못한 인수: $*"
  [[ $size_spec =~ $size_pattern ]] || die '-s는 0 또는 양의 정수 목록이어야 합니다.'
  [[ -z $jobs || $jobs =~ ^[1-9][0-9]*$ ]] || die '-j는 양의 정수여야 합니다.'
  [[ ${#jobs} -le 4 ]] || die '-j 값이 너무 큽니다.'
  IFS=, read -r -a sizes <<< "$size_spec"
  for size in "${sizes[@]}"; do
    [[ ${#size} -le 6 ]] || die '-s 값이 너무 큽니다 (최대 100000px).'
    ((size <= 100000)) || die '-s 값이 너무 큽니다 (최대 100000px).'
    ((size <= max)) || max=$size
    ((size != 0)) || original=1
  done
  select_tools
  cpu=$(cpu_count)

  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM HUP
  if ((check)); then
    KEEP=0
    RUN_DIR=$(mktemp -d "${TMPDIR:-/tmp}/arte10-check.XXXXXX")
    export OMP_NUM_THREADS=${OMP_NUM_THREADS:-2}
    export MAGICK_THREAD_LIMIT=${MAGICK_THREAD_LIMIT:-2}
    preflight "$RUN_DIR/probe"
    log "검사 완료: ImageMagick + G'MIC 필터 7종 / Soft Light=$SOFTLIGHT_MODE"
    return
  fi

  [[ -n $input && -d $input ]] || die "입력 폴더가 없습니다: $input"
  [[ -n $output ]] || die '결과 폴더를 지정하세요.'
  input=$(cd -P "$input" && pwd -P)
  mkdir -p "$output"
  output=$(cd -P "$output" && pwd -P)
  # Refuse an output ancestor of the source, including aliases via symlinks.
  [[ $output != / && $input != "$output" && $input != "$output/"* ]] ||
    die '결과 폴더는 입력 폴더와 같거나 입력의 상위 폴더일 수 없습니다.'

  for file in "$input"/*; do
    [[ -f $file ]] || continue
    case $file in
      *.[jJ][pP][gG]|*.[jJ][pP][eE][gG]|*.[pP][nN][gG]|*.[tT][iI][fF]|*.[tT][iI][fF][fF]|\
      *.[hH][eE][iI][cC]|*.[hH][eE][iI][fF]|*.[wW][eE][bB][pP]|*.[bB][mM][pP]|\
      *.[aA][vV][iI][fF]|*.[jJ][xX][lL]) inputs+=("$file") ;;
    esac
  done
  ((${#inputs[@]} > 0)) || die "입력 폴더에 지원되는 이미지가 없습니다: $input"
  total=$((${#inputs[@]} * ${#sizes[@]}))

  LOCK_DIR=$output/.arte10-main.lock
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    die "이 결과 폴더는 이미 사용 중이거나 잠겨 있습니다: $LOCK_DIR (비정상 종료 뒤 남은 잠금이면 실행 중인 작업이 없는지 확인하고 이 잠금 폴더만 삭제하세요.)"
  fi
  OWN_LOCK=1
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  if ((KEEP)); then
    [[ ! -L $output/_work ]] || die '_work는 심볼릭 링크일 수 없습니다.'
    mkdir -p "$output/_work"
    RUN_DIR=$(mktemp -d "$output/_work/run.XXXXXX")
  else
    RUN_DIR=$(mktemp -d "$output/.arte10-run.XXXXXX")
  fi
  mkdir "$RUN_DIR/names"
  # Reserving names on the destination filesystem catches case-folding/Unicode
  # collisions as well as cross-suffix collisions (photo vs photom5a).
  for size in "${sizes[@]}"; do
    tag=$(size_tag "$size" "${#sizes[@]}")
    for file in "${inputs[@]}"; do
      base=${file##*/}; base=${base%.*}; base=${base// /_}
      for suffix in "${SUFFIXES[@]}"; do
        dest=$base$suffix$tag.png
        if ! mkdir "$RUN_DIR/names/$dest" 2>/dev/null; then
          die "출력 이름이 충돌하거나 너무 깁니다: $dest (입력 이름·중복 크기를 확인하세요.)"
        fi
        [[ ! -L $output/$dest && ( ! -e $output/$dest || -f $output/$dest ) ]] ||
          die "결과 경로가 일반 파일이 아닙니다: $output/$dest"
        if [[ -e $output/$dest ]]; then
          for source_file in "${inputs[@]}"; do
            [[ ! $source_file -ef $output/$dest ]] || die "결과가 원본을 가리킵니다: $output/$dest"
          done
        fi
      done
    done
  done

  if [[ -z $jobs ]]; then
    jobs=1
    if ((original == 0)); then
      memory=$(memory_mb)
      # Conservative square-image estimate, not a guaranteed memory bound.
      estimate=$((512 + ((max * max + 999999) / 1000000) * 256))
      jobs=$((memory * 6 / 10 / estimate))
      ((jobs > 0)) || jobs=1
    fi
    ((jobs <= 4)) || jobs=4
    ((jobs <= cpu)) || jobs=$cpu
  fi
  ((jobs <= total)) || jobs=$total
  threads=$((cpu / jobs))
  ((threads > 0)) || threads=1
  ((threads <= 4)) || threads=4
  export OMP_NUM_THREADS=${OMP_NUM_THREADS:-$threads}
  export MAGICK_THREAD_LIMIT=${MAGICK_THREAD_LIMIT:-$threads}
  export ARTE10_RUN_DIR=$RUN_DIR ARTE10_OUT=$output ARTE10_KEEP=$KEEP
  preflight "$RUN_DIR/probe"

  if ((clean)); then
    for dest in "$RUN_DIR/names"/*; do
      rm -f "$output/${dest##*/}"
    done
  fi
  log "${#inputs[@]}장 × ${#sizes[@]}크기 → $((total * PER_IMAGE))장 / 동시 ${jobs}개 / 크기: $size_spec"
  log "입력: $input / 결과: $output"

  # Bounded FIFO workers use only Bash 3.2 features. Each worker is a fresh shell,
  # so checking wait statuses cannot disable errexit inside the image pipeline.
  for size in "${sizes[@]}"; do
    tag=$(size_tag "$size" "${#sizes[@]}")
    for file in "${inputs[@]}"; do
      if ((${#PIDS[@]} >= jobs)); then
        wait "${PIDS[0]}" || failed=1
        PIDS=("${PIDS[@]:1}")
      fi
      index=$((index + 1))
      base=${file##*/}; base=${base%.*}; base=${base// /_}
      "$BASH" "$self" --worker "$index" "$total" "$file" "$size" "$base" "$tag" &
      PIDS+=("$!")
    done
  done
  for pid in "${PIDS[@]}"; do wait "$pid" || failed=1; done
  PIDS=()
  for file in "$RUN_DIR"/ok.*; do finished=$((finished + 1)); done
  ((KEEP == 0)) || log "중간 이미지: $RUN_DIR"
  if ((failed || finished != total)); then
    die "$finished/${total}개 작업 완료. 실패한 사진은 위 단계별 오류를 확인하세요."
  fi
  log "완료: $((finished * PER_IMAGE))장 / $output ($((SECONDS - t0))초)"
}

main "$@"
