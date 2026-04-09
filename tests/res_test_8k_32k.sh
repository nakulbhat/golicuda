#!/usr/bin/env bash

# =======================
# User-editable settings
# =======================
GENERATIONS=1000            # fixed number of generations
TIMEOUT=30                  # seconds
CSV_FILE="results/res_scaling_8k_32k.csv"

# =======================
# Resolutions to test (presets)
# =======================
RESOLUTIONS=(
    "7680,4320"
    "15360,8640"
    "30720,17280"
    )

# =======================
# All valid flag combinations
# =======================
FLAGS=(
    "-r"
    "-c"
    "-e"
    "-rt"
    "-ct"
    "-et"
    "-rb"
    "-ra"
    "-cb"
    "-ca"
    "-eb"
    "-ea"
    "-rtb"
    "-rta"
    "-ctb"
    "-cta"
    "-etb"
    "-eta"
)

# =======================
# Write CSV header
# =======================
echo "res,${FLAGS[*]}" | sed 's/ /,/g' > "$CSV_FILE"

# =======================
# Main loop over resolutions
# =======================
for RES in "${RESOLUTIONS[@]}"; do
    echo "Running resolution: $RES"
    ROW=("$RES")
    for FLAG in "${FLAGS[@]}"; do
        # Run golicuda with timeout
        OUTPUT=$(timeout $TIMEOUT golicuda -H -s $RES -n $GENERATIONS $FLAG 2>perf_log.log)
        if [ $? -eq 124 ]; then
            # Timeout occurred
            echo "  $FLAG: timeout"
            ROW+=("")
        else
            # Extract total time in ms
            TOTAL=$(echo "$OUTPUT" | grep "Total" | awk '{print $3}')
            echo "  $FLAG: $TOTAL ms"
            ROW+=("$TOTAL")
        fi
    done
    # Write row to CSV
    echo "${ROW[*]}" | sed 's/ /,/g' >> "$CSV_FILE"
done

echo "Resolution benchmark complete. Results saved in $CSV_FILE"
