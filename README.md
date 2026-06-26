# fastMRI Breast: A publicly available radial k-space dataset of breast dynamic contrast-enhanced MRI

## Demonstration of DCE MRI reconstruction using temporal TV regularization

**Goal:** Make a publicly available radial k-space dataset of breast DCE-MRI which will promote development of fast and quantitative breast image reconstruction and machine learning methods.

> This is a fork of [eddysolo/demo_dce_recon](https://github.com/eddysolo/demo_dce_recon) with compatibility fixes for CuPy 13.x, absolute path support, and batch processing. See [CHANGES.md](CHANGES.md) for full details.

## Quick start

### 1. Clone this repository

```bash
git clone https://github.com/apenas-will/demo_dce_recon.git
cd demo_dce_recon
```

### 2. Set up the conda environment

**Option A — from the exported environment (recommended):**

```bash
conda env create -f environment.yml
conda activate dce
```

**Option B — manual install:**

```bash
conda create -n dce python=3.10
conda activate dce

conda install -c anaconda pip
python -m pip install torch torchvision torchaudio
python -m pip install tqdm pydicom numba scipy pywavelets h5py matplotlib

conda install -c conda-forge cupy cudnn cutensor nccl  # requires NVIDIA GPU
conda install -c conda-forge numpy=1.24
```

### 3. Install the custom SigPy fork

This project requires [ZhengguoTan/sigpy](https://github.com/ZhengguoTan/sigpy), which includes `HighDimensionalRecon`. The standard PyPI `sigpy` package will **not** work.

```bash
git clone https://github.com/ZhengguoTan/sigpy.git /tmp/sigpy_custom
cd /tmp/sigpy_custom
pip install -e .
cd -
```

**CuPy 13.x fix:** If you get `ModuleNotFoundError: No module named 'cupyx.cudnn'`, edit `sigpy/conv.py` line 359:

```diff
 if config.cudnn_enabled:  # pragma: no cover
-    from cupy import cudnn
+    import cupy.cuda.cudnn as cudnn
```

### 4. Download the data

The data is available for free through [fastMRI](https://fastmri.med.nyu.edu/). After acceptance of the dataset sharing agreement, you receive an email with download links.

Place the `.h5` files in a data directory, e.g.:

```
data/
├── fastMRI_breast_IDS_001_010/
│   ├── fastMRI_breast_001_1.h5
│   ├── fastMRI_breast_001_2.h5
│   └── ...
└── fastMRI_breast_IDS_011_020/
    ├── fastMRI_breast_011_1.h5
    └── ...
```

### 5. Run the reconstruction

**Single file, single slice (quick test):**

```bash
conda activate dce

python dce_recon.py \
    --dir /path/to/data/fastMRI_breast_IDS_001_010 \
    --data fastMRI_breast_001_1.h5 \
    --spokes_per_frame 12 \
    --slice_idx 0 \
    --slice_inc 1
```

**Single file, all 192 slices:**

```bash
python dce_recon.py \
    --dir /path/to/data/fastMRI_breast_IDS_001_010 \
    --data fastMRI_breast_001_1.h5 \
    --spokes_per_frame 12 \
    --slice_idx 0 \
    --slice_inc 192
```

**Convert reconstructed data to DICOM:**

```bash
python dcm_recon.py \
    --dcm GRASP_anno00001_anon.dcm \
    --h5py /path/to/data/fastMRI_breast_IDS_001_010/fastMRI_breast_001_1.h5 \
    --spokes_per_frame 12
```

**Batch processing (all files, reconstruction + DICOM):**

```bash
bash run_all_recon.sh
```

This processes all `.h5` files in both `fastMRI_breast_IDS_001_010` and `fastMRI_breast_IDS_011_020`, skipping files that already have a `_processed.h5` output.

### 6. Output structure

For each input file `fastMRI_breast_NNN_S.h5`, the pipeline produces:

```
data/fastMRI_breast_IDS_XXX_YYY/
├── fastMRI_breast_NNN_S.h5                  # original raw k-space
├── fastMRI_breast_NNN_S_processed.h5        # reconstructed images (HDF5)
└── fastMRI_breast_NNN_S_DCM_processed/      # DICOM series
    ├── slice_000_frame_000.dcm
    ├── slice_000_frame_001.dcm
    └── ...
```

The reconstructed HDF5 contains a dataset `temptv` with shape `(N_slices, N_frames, 320, 320)`.

For DICOM viewing, we recommend [FireVoxel](https://firevoxel.org/).

## Command-line arguments

### `dce_recon.py`

| Argument | Default | Description |
|---|---|---|
| `--dir` | `fastMRI_breast_001_1` | Directory containing the raw `.h5` file |
| `--data` | `fastMRI_breast_001_1.h5` | Filename of the raw k-space data |
| `--spokes_per_frame` | `12` | Number of radial spokes per temporal frame |
| `--slice_idx` | `0` | Starting slice index |
| `--slice_inc` | `1` | Number of slices to reconstruct |
| `--center_partition` | `31` | Center partition index |
| `--images_per_slab` | `192` | Total number of images per slab |

### `dcm_recon.py`

| Argument | Default | Description |
|---|---|---|
| `--dcm` | `GRASP_anno00001_anon.dcm` | DICOM template file for metadata |
| `--h5py` | — | Path to the raw `.h5` file (used to locate `_processed.h5`) |
| `--spokes_per_frame` | `13` | Number of spokes per frame |
| `--partitions` | `83` | Total number of partitions |
| `--TE` | `1.8` | Echo time (ms) |
| `--TR` | `4.87` | Repetition time (ms) |

## fastMRI Breast dataset

The data are available for free through [fastMRI](https://fastmri.med.nyu.edu/). After acceptance of the dataset sharing agreement, researchers receive an email containing links to download the data. The provided DICOM files are in 4D (x, y, z, time) with 4 time frames.

Our dataset also includes case-level labels arranged in an excel file (`breast_fastMRI_final.xlsx`) indicating patient age, menopause status, lesion status (negative, benign, and malignant), and lesion type for each case.

## Citation

If you use the fastMRI DCE Breast data or code in your research, please cite our paper: https://pubs.rsna.org/doi/10.1148/ryai.240345

## References

* Zhang S, Block KT, Frahm J. [Magnetic resonance imaging in real time: advances using radial FLASH](https://doi.org/10.1002/jmri.21987). J Magn Reson Imaging 2010;31:101-109.

* Uecker M, Zhang S, Voit D, Karaus A, Merboldt KD, Frahm J. [Real-time MRI at a resolution of 20 ms](https://doi.org/10.1002/nbm.1585). NMR Biomed 2010;23:986-994.

* Block KT, Chandarana H, Milla S, Bruno M, Mulholland T, Fatterpekar G, Hagiwara M, Grimm R, Geppert C, Kiefer B, Sodickson DK. [Towards routine clinical use of radial stack-of-stars 3D gradient-echo sequences for reducing motion sensitivity](https://doi.org/10.13104/jksmrm.2014.18.2.87). J Korean Magn Reson Med 2014;18:87-106.

* Feng L, Grimm R, Block KT, Chandarana H, Kim S, Xu J, Axel L, Sodickson DK, Otazo R. [Golden-angle radial sparse parallel MRI: combination of compressed sensing, parallel imaging, and golden-angle radial sampling for fast and flexible dynamic volumetric MRI](https://doi.org/10.1002/mrm.24980). Magn Reson Med 2014;72:707-717.
