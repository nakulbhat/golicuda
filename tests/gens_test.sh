#!/usr/bin/env bash

# =======================
# User-editable settings
# =======================
GENERATIONS=(5 10 25 50 100 250 500 1000 2500 5000 10000 25000 50000 100000 250000 500000 1000000)
RESOLUTION="480p"     # can also set -s WIDTHxHEIGHT
CSV_FILE="results/gens_power.csv"

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
echo "gens,${FLAGS[*]}" | sed 's/ /,/g' > "$CSV_FILE"

# =======================
# Main loop over generations
# =======================
for GEN in "${GENERATIONS[@]}"; do
    echo "Running generation: $GEN"
    ROW=("$GEN")
    for FLAG in "${FLAGS[@]}"; do
        # Run golicuda with timeout
        OUTPUT=$(golicuda -H -s $RESOLUTION -n $GEN $FLAG 2>perf_log.log)
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

echo "Benchmark complete. Results saved in $CSV_FILE"
