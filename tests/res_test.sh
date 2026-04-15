#!/usr/bin/env bash

# =======================
# User-editable settings
# =======================
GENERATIONS=1000            # fixed number of generations
CSV_FILE="results/res_scaling.csv"

# =======================
# Resolutions to test (presets)
# =======================
RESOLUTIONS=(
    "5,5"
    "10,10"
    "25,25"
    "50,50"
    "100,100"
    "250,250"
    "500,500"
    "750,750"
    "1000,1000"
    "1500,1500"
    "2000,2000"
    "3000,3000"
    "4000,4000"
    "5000,5000"
    "7500,7500"
    "10000,10000"
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
        OUTPUT=$(golicuda -H -s $RES -n $GENERATIONS $FLAG 2>perf_log.log)
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
