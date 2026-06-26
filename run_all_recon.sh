#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_ROOT="$(dirname "$SCRIPT_DIR")/data"
SPOKES=12

for DATA_DIR in "$DATA_ROOT/fastMRI_breast_IDS_001_010" "$DATA_ROOT/fastMRI_breast_IDS_011_020"; do
    echo "=== Processing directory: $DATA_DIR ==="
    for H5 in "$DATA_DIR"/fastMRI_breast_*.h5; do
        BASENAME=$(basename "$H5")
        # skip already-processed files
        if [[ "$BASENAME" == *_processed.h5 ]]; then
            continue
        fi
        OUTFILE="$DATA_DIR/${BASENAME%.h5}_processed.h5"
        if [ -f "$OUTFILE" ]; then
            echo ">>> SKIP $BASENAME (already processed)"
            continue
        fi
        echo ">>> Processing $BASENAME"
        python "$SCRIPT_DIR/dce_recon.py" \
            --dir "$DATA_DIR" \
            --data "$BASENAME" \
            --spokes_per_frame $SPOKES \
            --slice_idx 0 \
            --slice_inc 192

        echo ">>> Converting to DICOM: $BASENAME"
        python "$SCRIPT_DIR/dcm_recon.py" \
            --dcm "$SCRIPT_DIR/GRASP_anno00001_anon.dcm" \
            --h5py "$DATA_DIR/$BASENAME" \
            --spokes_per_frame $SPOKES
    done
done

echo "=== All done ==="
