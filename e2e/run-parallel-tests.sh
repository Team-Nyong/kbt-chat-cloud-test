#!/bin/bash

# 20개 서버를 5개씩 병렬로 테스트
# goorm-ktb-001 ~ goorm-ktb-020

RESULTS_DIR="./test-results-batch"
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# 전체 결과 저장 파일
SUMMARY_FILE="$RESULTS_DIR/summary.txt"
FAIL_DETAIL_FILE="$RESULTS_DIR/fail_details.txt"
> "$SUMMARY_FILE"
> "$FAIL_DETAIL_FILE"

run_batch() {
    local start=$1
    local end=$2
    local pids=()
    local nums=()

    echo ""
    echo "=========================================="
    echo " 배치 테스트: goorm-ktb-$(printf '%03d' $start) ~ goorm-ktb-$(printf '%03d' $end)"
    echo "=========================================="

    for i in $(seq $start $end); do
        num=$(printf '%03d' $i)
        base_url="https://chat.goorm-ktb-${num}.goorm.team"
        result_file="$RESULTS_DIR/result-${num}.json"

        # 백그라운드에서 테스트 실행 (로그 숨김)
        (
            BASE_URL="$base_url" npx playwright test --reporter=json 2>/dev/null > "$result_file"
        ) &
        pids+=($!)
        nums+=("$num")
    done

    # 모든 백그라운드 프로세스 완료 대기
    for pid in "${pids[@]}"; do
        wait $pid
    done

    echo ""
    # 배치 결과 출력
    for num in "${nums[@]}"; do
        result_file="$RESULTS_DIR/result-${num}.json"

        if [ -f "$result_file" ] && [ -s "$result_file" ]; then
            # JSON에서 stats 파싱 (python3 사용)
            stats=$(python3 -c "
import json
try:
    with open('$result_file', 'r') as f:
        data = json.load(f)
    stats = data.get('stats', {})
    print(f\"{stats.get('expected', 0)}|{stats.get('unexpected', 0)}|{stats.get('skipped', 0)}\")
except:
    print('0|0|0')
" 2>/dev/null)

            expected=$(echo "$stats" | cut -d'|' -f1)
            unexpected=$(echo "$stats" | cut -d'|' -f2)
            skipped=$(echo "$stats" | cut -d'|' -f3)

            if [ -n "$expected" ] && [ "$expected" != "0" -o "$unexpected" != "0" ]; then
                expected=${expected:-0}
                unexpected=${unexpected:-0}

                if [ "$unexpected" -eq 0 ]; then
                    echo "  ✅ goorm-ktb-${num}: PASS ($expected passed)"
                    echo "PASS|${num}|${expected}|0" >> "$SUMMARY_FILE"
                else
                    echo "  ❌ goorm-ktb-${num}: FAIL ($unexpected failed, $expected passed)"

                    # 실패한 테스트 제목 추출 (status가 unexpected 또는 failed인 것)
                    # suites > specs > tests 구조에서 실패한 테스트 찾기
                    failed_tests=$(python3 -c "
import json
import sys
try:
    with open('$result_file', 'r') as f:
        data = json.load(f)

    failed = []
    for suite in data.get('suites', []):
        suite_title = suite.get('title', '')
        for spec in suite.get('specs', []):
            spec_title = spec.get('title', '')
            for test in spec.get('tests', []):
                if test.get('status') in ['unexpected', 'failed']:
                    full_title = f'{suite_title} > {spec_title}'
                    if full_title not in failed:
                        failed.append(full_title)
        # nested suites
        for sub_suite in suite.get('suites', []):
            sub_title = sub_suite.get('title', '')
            for spec in sub_suite.get('specs', []):
                spec_title = spec.get('title', '')
                for test in spec.get('tests', []):
                    if test.get('status') in ['unexpected', 'failed']:
                        full_title = f'{suite_title} > {sub_title} > {spec_title}'
                        if full_title not in failed:
                            failed.append(full_title)

    for f in failed[:5]:
        print(f)
except:
    pass
" 2>/dev/null)

                    if [ -n "$failed_tests" ]; then
                        echo "$failed_tests" | while IFS= read -r line; do
                            echo "      → $line"
                        done
                        # 상세 정보 저장
                        echo "SERVER:${num}" >> "$FAIL_DETAIL_FILE"
                        echo "$failed_tests" >> "$FAIL_DETAIL_FILE"
                        echo "---" >> "$FAIL_DETAIL_FILE"
                    fi

                    echo "FAIL|${num}|${expected}|${unexpected}" >> "$SUMMARY_FILE"
                fi
            else
                # stats 파싱 실패 - JSON 파일 자체에 문제가 있는 경우
                error_check=$(grep -c '"error"' "$result_file" 2>/dev/null || echo "0")
                if [ "$error_check" -gt 0 ]; then
                    echo "  ❌ goorm-ktb-${num}: ERROR (테스트 실행 실패)"
                    echo "ERROR|${num}|0|0" >> "$SUMMARY_FILE"
                    echo "SERVER:${num}" >> "$FAIL_DETAIL_FILE"
                    echo "테스트 실행 자체 실패" >> "$FAIL_DETAIL_FILE"
                    echo "---" >> "$FAIL_DETAIL_FILE"
                else
                    echo "  ⚠️  goorm-ktb-${num}: 결과 파싱 실패"
                    echo "ERROR|${num}|0|0" >> "$SUMMARY_FILE"
                fi
            fi
        else
            echo "  ❌ goorm-ktb-${num}: ERROR (결과 파일 없음)"
            echo "ERROR|${num}|0|0" >> "$SUMMARY_FILE"
            echo "SERVER:${num}" >> "$FAIL_DETAIL_FILE"
            echo "결과 파일 없음" >> "$FAIL_DETAIL_FILE"
            echo "---" >> "$FAIL_DETAIL_FILE"
        fi
    done
}

# 시작 시간 기록
start_time=$(date +%s)
echo ""
echo "============================================================"
echo " E2E 테스트 시작: $(date '+%Y-%m-%d %H:%M:%S')"
echo " 대상: goorm-ktb-001 ~ goorm-ktb-020 (5개씩 병렬 실행)"
echo "============================================================"

# 테스트할 범위 설정 (인자로 받거나 기본값 사용)
START=${1:-1}
END=${2:-20}

echo " 테스트 범위: goorm-ktb-$(printf '%03d' $START) ~ goorm-ktb-$(printf '%03d' $END)"

# 5개씩 배치로 실행
current=$START
while [ $current -le $END ]; do
    batch_end=$((current + 4))
    if [ $batch_end -gt $END ]; then
        batch_end=$END
    fi
    run_batch $current $batch_end
    current=$((batch_end + 1))
done

# 종료 시간 및 전체 결과 출력
end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))

echo ""
echo ""
echo "============================================================"
echo " 전체 테스트 결과 요약"
echo "============================================================"
echo ""

pass_count=0
fail_count=0
fail_servers=""

for i in $(seq $START $END); do
    num=$(printf '%03d' $i)
    result=$(grep "|${num}|" "$SUMMARY_FILE" 2>/dev/null)

    if [ -n "$result" ]; then
        status=$(echo "$result" | cut -d'|' -f1)
        passed=$(echo "$result" | cut -d'|' -f3)
        failed=$(echo "$result" | cut -d'|' -f4)

        if [ "$status" = "PASS" ]; then
            echo "  ✅ goorm-ktb-${num}: PASS ($passed tests)"
            pass_count=$((pass_count + 1))
        else
            echo "  ❌ goorm-ktb-${num}: FAIL ($failed failed)"
            fail_count=$((fail_count + 1))
            fail_servers="$fail_servers $num"
        fi
    else
        echo "  ⚠️  goorm-ktb-${num}: 결과 없음"
        fail_count=$((fail_count + 1))
    fi
done

echo ""
echo "------------------------------------------------------------"
echo " 통계: ${pass_count}개 성공 / ${fail_count}개 실패"
echo " 소요 시간: ${minutes}분 ${seconds}초"
echo "------------------------------------------------------------"

# 실패한 서버 상세 정보 출력
if [ -s "$FAIL_DETAIL_FILE" ]; then
    echo ""
    echo ""
    echo "============================================================"
    echo " 실패 상세 내역"
    echo "============================================================"

    current_server=""
    while IFS= read -r line; do
        if [[ "$line" == SERVER:* ]]; then
            current_server="${line#SERVER:}"
            echo ""
            echo "  [goorm-ktb-${current_server}]"
        elif [[ "$line" != "---" ]] && [[ -n "$line" ]]; then
            echo "    - $line"
        fi
    done < "$FAIL_DETAIL_FILE"
fi

echo ""
echo "============================================================"
