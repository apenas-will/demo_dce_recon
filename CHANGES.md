# Changes Required to Run the DCE Reconstruction Pipeline

## 1. Install custom SigPy fork in the `dce` conda environment

The project depends on a forked version of SigPy with `HighDimensionalRecon` support, not the standard PyPI package.

```bash
git clone https://github.com/ZhengguoTan/sigpy.git /tmp/sigpy_custom
conda run -n dce pip install -e /tmp/sigpy_custom
```

## 2. Fix `cupyx.cudnn` import incompatibility (SigPy + CuPy 13.x)

CuPy 13.x removed the `cupyx.cudnn` module. SigPy's `conv.py` imports `from cupy import cudnn`, which internally calls `from cupyx.cudnn import *` and fails.

**File:** `sigpy/conv.py` (line 359)

```diff
 if config.cudnn_enabled:  # pragma: no cover
-    from cupy import cudnn
+    import cupy.cuda.cudnn as cudnn
```

`cupy.cuda.cudnn` is the correct low-level module that still exists in CuPy 13.x.

## 3. Fix coil sensitivity map dimension ordering

The original code inserted the slab dimension (`Nz=1`) before the coil dimension, causing a shape mismatch in `HighDimensionalRecon`.

SigPy's dimension convention (from `sigpy/mri/dims.py`):
```
[..., Ntime, Necho, Ncoil, Nz, Ny, Nx]
```

`EspiritCalib` returns shape `(num_maps, Ncoil, Ny, Nx)`. The `Nz` dimension must be inserted **after** `Ncoil`, not before it.

**File:** `dce_recon.py` (line 159)

```diff
-        C = C[:, None, :, :]   # produced (1, 1, 16, 320, 320) — shape[-4] = 1, wrong
+        C = C[:, :, None, :, :]  # produces (1, 16, 1, 320, 320) — shape[-4] = 16, correct
```

## 4. Fix output file path for absolute directory paths

The original output path concatenated `args.dir` twice, which breaks when using absolute paths.

**File:** `dce_recon.py` (line 185)

```diff
-    f = h5py.File(OUT_DIR + '/' + args.dir + '_processed.h5', 'w')
+    data_base = os.path.splitext(args.data)[0]
+    f = h5py.File(os.path.join(OUT_DIR, data_base + '_processed.h5'), 'w')
```

## 5. Fix CuPy-to-NumPy implicit conversion error

CuPy 13.x disallows implicit conversion to NumPy arrays. `sp.to_device()` on a list of CuPy arrays does not automatically produce NumPy arrays.

**File:** `dce_recon.py` (line 177–178)

```diff
-    acq_slices = cp.array(acq_slices)
-    acq_slices = cp.asnumpy(acq_slices)
-    acq_slices = np.squeeze(abs(acq_slices))
+    acq_slices = np.array([sp.to_device(s) for s in acq_slices])
+    acq_slices = np.squeeze(np.abs(acq_slices))
```

The `import cupy as cp` line was also removed since it is no longer needed.

## 6. Fix DICOM converter path handling (`dcm_recon.py`)

The original DICOM converter hardcoded paths relative to the script directory, breaking with absolute input paths.

**File:** `dcm_recon.py` (lines 49–54)

```diff
-    OUT_DIR = DIR + '/' + args.h5py  + '/' + args.h5py + '_DCM_processed'
-    OUT_DIR = OUT_DIR.split('.h5')[0]
-    pathlib.Path(OUT_DIR).mkdir(parents=True, exist_ok=True)
-
-    f = h5py.File(DIR + '/' + args.h5py + '/' + args.h5py + '_processed.h5', 'r')
+    h5_base = os.path.splitext(os.path.basename(args.h5py))[0]
+    h5_dir = os.path.dirname(os.path.abspath(args.h5py))
+
+    OUT_DIR = os.path.join(h5_dir, h5_base + '_DCM_processed')
+    pathlib.Path(OUT_DIR).mkdir(parents=True, exist_ok=True)
+
+    processed_path = os.path.join(h5_dir, h5_base + '_processed.h5')
+    f = h5py.File(processed_path, 'r')
```

## 7. Fix DICOM converter for single-slice reconstructions

When only one slice is reconstructed, `np.squeeze` removes the Z dimension entirely, leaving a 3D array `(N_t, N_y, N_x)` instead of the expected 4D `(N_z, N_t, N_y, N_x)`.

**File:** `dcm_recon.py` (line 60)

```diff
     R = np.squeeze(abs(R))
+
+    if R.ndim == 3:
+        R = R[np.newaxis, ...]

     R = np.flip(R, axis=(-2, -1))
```

## Batch execution

A helper script `run_all_recon.sh` was created to process all `.h5` files from both data directories (`fastMRI_breast_IDS_001_010` and `fastMRI_breast_IDS_011_020`), with reconstruction followed by DICOM conversion. Files that already have a corresponding `_processed.h5` output are skipped.

```bash
conda run -n dce bash run_all_recon.sh
```
