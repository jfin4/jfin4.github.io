# CEDEN Dataset Reformatting Playbook: California Integrated Report (303(d)) Datasets

[John Inman](/)

2025-09-17

## Document Control & Purpose

-   **Target Audience:** Automated execution agent (and supporting data engineers) responsible for writing and running R reformatting scripts.
-   **Objective:** Transform heterogeneous water quality assessment reference datasets in `./refs/` (and archives extracted to `./refs_extracted/`) into standardized, CEDEN-compliant Comma-Separated Values (`.csv`) data files stored in `./output/`, with comprehensive sidecar metadata CSV files (`_metadata.csv`).
-   **Target Schema:** California Environmental Data Exchange Network (CEDEN) submission format, primarily modeled on the **CEDEN FieldResults** schema (water chemistry, field measurements, sediment, tissue chemistry, and continuous sensor data).
-   **Output Formats:**
    -   **Reformatted Data:** Standard RFC 4180 Comma-Separated Values (`.csv`).
    -   **Metadata Sidecar:** Standard RFC 4180 Comma-Separated Values (`_metadata.csv`).
-   **Execution Mandate:** This document is a concrete, numbered operational playbook. Every transformation, column mapping, controlled vocabulary (CV) crosswalk, and validation rule must be executed exactly as specified. No code is contained in this document; this document serves as the formal specification for the R scripts to be written by the executing agent.

------------------------------------------------------------------------

## 1. Executive Summary & Non-Negotiable Rules

### 1.1 Context

The files in `./refs/` comprise water quality monitoring datasets collected across California for the Clean Water Act Section 303(d) / 305(b) Integrated Report. The reference files originate from regional water boards, municipalities, state and federal agencies (e.g., USGS, DPR, DWR, SWAMP, CCAMP), academic institutions, and citizen monitoring groups. The collection includes approximately 1,322 top-level reference files and thousands of extracted sub-files spanning standard modern CEDEN/SWAMP templates, legacy flat spreadsheets, wide analyte-by-sheet workbooks, continuous logger text files, relational database extracts, and supporting Quality Assurance Project Plans (QAPPs).

### 1.2 Non-Negotiable Operational Rules

The executing agent must strictly enforce the following six rules without exception. Any script that violates these rules will produce invalid regulatory data.

1.  **Rule 1: Never guess a value (Strict MDL / RL Rule).**
    -   If Method Detection Limit (MDL) or Reporting Limit (RL) is missing, unrecorded, blank, or represented by sentinel values (`-88`, `-99`, `Not Recorded`, `NR`, `ND`) in the raw data, search the associated QAPP PDF or document for that reference ID.
    -   If an explicit detection limit table in the associated QAPP defines the MDL/RL for that exact analyte and method, populate the value and record `rule_1_mdl_rl_provenance = "extracted_from_qapp"` in the metadata CSV.
    -   If the value cannot be verified with certainty from an associated QAPP, leave it as `NA` (empty string in output CSV). **Never invent, interpolate, or guess detection limits.** Document the missing values in `_metadata.csv`.
2.  **Rule 2: Never create a synthetic StationCode.**
    -   If a station code is missing, blank, or unrecorded in the source data, leave it as an empty string (`""` / `NA`).
    -   **Never synthesize or fabricate station codes** (e.g., do not generate `STATION_001`, `UNKNOWN_SITE`, or `REF4708_SITE_A`).
    -   Flag every record with a missing station code in the sidecar metadata CSV under `blank_station_codes_count`.
3.  **Rule 3: Never approximate coordinates.**
    -   Coordinates (`TargetLatitude`, `TargetLongitude`, `Datum`) must originate strictly from the source data or from an exact match in CEDEN's official `StationLookUp` list.
    -   **Never approximate, geocode by street name, interpolate, or assign waterbody centroids.** If coordinates are absent in both the source record and `StationLookUp`, leave latitude and longitude empty (`NA`).
4.  **Rule 4: Never alter a numeric result value.**
    -   All numeric measurements must pass through exactly as read from the source.
    -   Do not round, truncate, trim significant digits, or apply conversion factors to numeric results.
    -   For non-detect measurements where the qualifier is embedded in the string (e.g., `< 0.05`), extract the numeric component (`0.05`) verbatim as `Result` and assign the non-detect qualifier to `ResQualCode`. Do not alter the value `0.05`.
5.  **Rule 5: Strict row dropping criterion.**
    -   A row may be dropped **if and only if** it is completely unparseable: [Drop Row ⇔ is.na(*StationCode*) ∧ is.na(*AnalyteName*) ∧ is.na(*Result*)]{.math .display}
    -   Rows meeting this condition represent blank rows, separator lines, or sheet summary blocks (e.g., "Average: 14.2", "Total Samples: 100").
    -   If a row contains an AnalyteName and a Result, even if StationCode is missing: **DO NOT DROP IT.** Retain the record, leave StationCode blank, and record the missing station code in the metadata CSV.
6.  **Rule 6: Mandatory metadata sidecar for every dataset.**
    -   Every single `.csv` dataset generated in `./output/` must be accompanied by an identical-basename CSV sidecar file (`<filename>_metadata.csv`).
    -   The metadata CSV must document every column mapping applied, CV match counts, unmatched values, raw vs. output row counts, dropped summary row counts, and data quality flags using the standardized 4-column schema (`Section`, `Property`, `Value`, `Notes`).

------------------------------------------------------------------------

## 2. Directory Architecture & Environment Setup

### 2.1 Directory Layout

The executing agent must establish and operate within the following standardized directory tree:

    /workspace/
    ├── refs/                       # Read-only source datasets (1,322+ files: .xlsx, .xls, .zip, .csv, .txt, .pdf, .doc)
    ├── refs_extracted/             # Working directory for extracted archive contents (partitioned by ref ID)
    │   ├── ref36/
    │   ├── ref428/
    │   ├── ref3656/
    │   └── ...
    ├── cv_lookups/                 # Local cache of CEDEN Controlled Vocabulary lookup lists (.csv)
    │   ├── AnalyteLookUp.csv
    │   ├── UnitLookUp.csv
    │   ├── MatrixLookUp.csv
    │   ├── FractionLookUp.csv
    │   ├── MethodLookUp.csv
    │   ├── CollectionMethodLookUp.csv
    │   ├── SampleTypeLookUp.csv
    │   ├── ResQualLookUp.csv
    │   ├── QALookUp.csv
    │   └── StationLookUp.csv
    ├── res/                        # Integrated Report assessments & S-drive index
    │   ├── ComprehensiveReportTab.txt
    │   └── s-drive.txt
    ├── output/                     # Production target for reformatted datasets and CSV sidecars
    │   ├── ref4708_WaterSedimentField.csv
    │   ├── ref4708_WaterSedimentField_metadata.csv
    │   ├── ref5865_Field.csv
    │   ├── ref5865_Field_metadata.csv
    │   └── ...
    └── logs/                       # Batch execution logs and error traces
        ├── extraction.log
        ├── reformatting.log
        └── cv_validation.log

### 2.2 Environment & Package Prerequisites

The executing agent must verify that the following R packages are loaded and available in the execution environment:

1.  `readxl` --- Reading `.xls` (BIFF8) and `.xlsx` (OpenXML) workbooks.
2.  `readr` --- High-performance reading and writing of standardized CSV files (`read_csv`, `write_csv`).
3.  `data.table` --- High-performance data manipulation, joining, filtering, and fast CSV export (`fwrite`).
4.  `dplyr` & `tidyr` --- Relational operations, schema reshaping (pivoting wide-to-long).
5.  `lubridate` --- Standardizing heterogeneous date and time formats into ISO-8601 (`YYYY-MM-DD`, `HH:MM:SS`).
6.  `stringr` --- Regular expressions, text cleaning, whitespace trimming.
7.  `purrr` --- Functional iteration over sheets and files.
8.  `foreign` --- Reading legacy DBF attribute tables (`read.dbf`) found in GIS archives.

------------------------------------------------------------------------

## 3. Phase 1: Archive Extraction & Pre-Processing Playbook

### 3.1 Extraction Specification

All compressed archives (`.zip`) in `./refs/` must be extracted systematically prior to tabular parsing.

1.  **Extraction Target Directory:** Extract each archive `refs/ref<ID>.zip` into a dedicated subdirectory: [Extraction Path: ./*refs*\_*extracted*/*ref*⟨*ID*⟩/]{.math .display} Example: `refs/ref4448.zip` extracts to `./refs_extracted/ref4448/`.

2.  **Recursive Archive Handling:** Certain archives contain nested zip files (e.g., `ref2518.zip` contains `Benthic.zip`, `Chemistry.zip`, `ToxData.zip`, `TrawlData.zip`).

    -   The extraction algorithm must scan `./refs_extracted/ref<ID>/` for any `.zip` files.
    -   For every child zip located at `./refs_extracted/ref<ID>/path/subarchive.zip`, extract its contents into `./refs_extracted/ref<ID>/path/subarchive_extracted/`.
    -   Repeat recursively until no unextracted `.zip` files remain.

3.  **Artifact Sanitization:** During or immediately following extraction, prune operating system artifacts and corrupt non-data files:

    -   Delete all directories named `__MACOSX` and all contents therein.
    -   Delete all files matching `.*` (hidden files, e.g., `.DS_Store`).
    -   Delete all temporary lock files matching `~$*.xlsx` or `~$*.xls`.

4.  **Standalone vs. Extracted Archive Precedence:** In approximately 147 instances, a reference ID exists as both a standalone spreadsheet (e.g., `refs/ref4448.xlsx`) and an archive (e.g., `refs/ref4448.zip` containing `ShastaTailwaterReduction_WaterChem_Sediment_Field.xlsx`).

    -   The executing script must inspect both files.
    -   If the spreadsheet inside the archive is identical in sheet structure and row count to the standalone file, process the standalone file and note archive redundancy in metadata.
    -   If the archive contains additional sheets, supplementary data files (e.g., separate water and habitat workbooks), or more comprehensive column headers, process each distinct data file as an independent sub-dataset:
        -   Target naming convention: `ref<ID>_<subfilename>_<sheetname>.csv`.

5.  **File Provenance Tracking:** Every record processed from an extracted file must retain its exact origin:

    -   `RefID`: e.g., `"ref4448"`
    -   `SourceArchive`: e.g., `"refs/ref4448.zip"` (or `NA` if standalone)
    -   `SourceFile`: e.g., `"refs_extracted/ref4448/ShastaTailwaterReduction/ShastaTailwaterReduction_WaterChem_Sediment_Field.xlsx"`
    -   `SourceSheet`: e.g., `"WaterSedimentField"`

------------------------------------------------------------------------

## 4. Phase 2: Source File Inventory & Archetype Classification Playbook

### 4.1 Archetype Classification Matrix

Every file in `./refs/` and `./refs_extracted/` must be classified into one of the following eight operational archetypes:

  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Archetype Code    Description                             Key Identifying Signatures                                                                                                                                    Primary Action
  ----------------- --------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------
  **ARCH-1**        **Modern CEDEN / SWAMP Export**         Sheets named `WaterSedimentField`, `Water`, `Field`, `Habitat`, `Tissue`, `Benthic`, `Toxicity` with 50+ standardized columns. Often has `ReadMe` sheet.      Direct column-to-column mapping to CEDEN schema; emit `.csv`.

  **ARCH-2**        **CIWQS Regulatory Export**             Sheet named `CIWQS` with 65 standardized columns (`WQID`, `StationCode`, `AnalyteName`, `Result`, etc.).                                                      Direct column-to-column mapping; emit `.csv`.

  **ARCH-3**        **WQX / Water Quality Portal Export**   Sheet named `WQX` or `WaterQualityPortal` with national WQX header layout.                                                                                    Map WQX column aliases to CEDEN target names; emit `.csv`.

  **ARCH-4**        **CCAMP / Regional Board Formats**      Sheets named `Ccamp_WQ_Data`, `Swamp_WQ_Data`, `SQL_Query_Results` with 45 columns (`LabSampleID`, `StationCode`, `ResultQualCode`, `ccampid`).               Apply CCAMP column crosswalk dictionary; emit `.csv`.

  **ARCH-5**        **CDPR Pesticide Database**             Sheet named `CDPR_Data` or text files like `ref2966.txt`. Columns: `County_Name`, `site description`, `chemical`, `date`, `Conc [ug/L]`, `loq`, `study_cd`.   Reformat CDPR columns; generate default units and fractions; emit `.csv`.

  **ARCH-6**        **Analyte-Per-Sheet Workbooks**         Multiple sheets named after chemical constituents (e.g., `ref2427.xls` with sheets `Arsenic`, `Copper`, `E. coli`, `Lead`, `Turbidity`).                      Extract analyte name from sheet title or `Analyte` column; iterate and append rows; emit `.csv`.

  **ARCH-7**        **Wide Matrix / Station-Per-Sheet**     Sheets named after stations (e.g., `USGS9427520`) or waterbodies (`Lake Oroville`, `MET_WET`). Wide columns for each analyte (`AS_W`, `PB_W`, `HG_W`).        Pivot wide columns to long format (`AnalyteName`, `Result`); emit `.csv`.

  **ARCH-8**        **Delimited Continuous / Probe Data**   CSV/TXT logger files (e.g., `ref3697.txt`, `ref4503.csv`, `ref6628.csv`) with metadata header blocks followed by time series.                                 Skip non-tabular header rows; parse timestamp and parameter values; emit `.csv`.

  **DOC-META**      **Supporting Documents / QAPP**         `.pdf`, `.doc`, `.docx` files. Often titled `*QAPP*`, `*Report*`, `*QA*`.                                                                                     Do **not** parse as tabular results. Scan during Phase 7 for missing MDL/RL lookups.

  **NON-DATA**      **Ancillary Media / GIS**               `.jpg`, `.png`, `.html`, `.msg`, `.isc`, `.dat` (raw binary sensor files).                                                                                    Ignore for tabular data; catalog in reference index. If `.dbf` contains station coordinates, use for coordinate lookup.
  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### 4.2 Sheet Filtering & Triage Specification

When an Excel workbook is opened:

1.  **Scan Sheet Names:** Retrieve all sheet names via `readxl::excel_sheets()`.
2.  **Identify Metadata Sheets:** Do **not** process sheets named `ReadMe`, `Readme`, `README`, `Title`, `title`, `Table of contents`, `Qualifier Definitions`, `StationCode List`, `Delisting Criteria`, `Notes`, `Study References`, `BPExceedance Tables`, or `Graphs` as result tables.
    -   Instead, read `ReadMe` sheets to extract project-level metadata (`Parent Project`, `Data Source`, `QAPPCode`, `Data Dictionary URL`). Store these attributes in memory to populate missing project metadata.
3.  **Select Target Data Sheets:**
    -   If an ARCH-1 sheet exists (`WaterSedimentField`, `Water`, `Field`, `Habitat`, `Tissue`, `Benthic`, `Toxicity`), select and process each of those sheets independently.
    -   If an ARCH-2 or ARCH-3 sheet exists (`CIWQS`, `WQX`), select and process.
    -   If sheets correspond to chemical names (ARCH-6), process all chemical sheets that contain data rows.
    -   If only generic sheets exist (`Sheet1`, `Sheet 1`, `Data`), inspect row headers to determine archetype.

### 4.3 Leading Metadata & Header Detection Algorithm

Many older spreadsheets (e.g., `ref2452.xls`, `ref2666.xls`, `ref2473.xls`, `ref4503.csv`) feature leading title blocks, qualifier definitions, or station metadata in the first 1 to 15 rows before the actual data header appears.

The executing script must implement the following header detection logic:

1.  Read the first 25 rows of the worksheet with `col_names = FALSE`.
2.  For each row [*i* ∈ {1, ..., 25}]{.math .inline}:
    -   Convert row values to character strings, trim whitespace, and discard empty strings.
    -   Compute a **Header Match Score** ([*S*~*i*~]{.math .inline}) based on the count of matching CEDEN keyword tokens: [*S*~*i*~ = ∑𝕀(token ∈ {\"station\", \"sample\", \"date\", \"time\", \"analyte\", \"parameter\", \"result\", \"matrix\", \"method\", \"unit\", \"qualifier\", \"latitude\", \"longitude\"})]{.math .display}
3.  **Decision Rule:**
    -   The header row is the row index [*k*]{.math .inline} that maximizes [*S*~*k*~]{.math .inline}, provided [*S*~*k*~ ≥ 3]{.math .inline}.
    -   If the first row already has [*S*~1~ ≥ 3]{.math .inline}, set header row [*k* = 1]{.math .inline}.
    -   If [*k* \> 1]{.math .inline}, re-read the sheet setting `skip = k - 1` and `col_names = TRUE`.
    -   Any metadata in rows [1]{.math .inline} to [*k* − 1]{.math .inline} (such as station coordinates embedded in a title block) must be parsed into an auxiliary metadata dictionary.

### 4.4 Row Filtering & Summary Row Dropping Specification

Once the tabular data is read into memory:

1.  **Evaluate Rule 5 Criterion:** For every row [*r*]{.math .inline}, evaluate whether: [is.na(*r*.StationCode) ∧ is.na(*r*.AnalyteName) ∧ is.na(*r*.Result)]{.math .display}
2.  **Execution Action:**
    -   If **TRUE**: Drop row [*r*]{.math .inline}. Increment `rows_dropped_unparseable` counter.
    -   If **FALSE**: Retain row [*r*]{.math .inline}.
3.  **Accounting:** Record in `_metadata.csv`:
    -   `raw_rows_read`: Total rows loaded after header.
    -   `rows_dropped_unparseable`: Total rows meeting the Rule 5 drop criterion.
    -   `output_rows`: Total rows written to `.csv` (`raw_rows_read - rows_dropped_unparseable`).

------------------------------------------------------------------------

## 5. Phase 3: CEDEN Target Schema Specification

The standardized output table matches the **CEDEN FieldResults** schema (57 standardized columns). Every output `.csv` file must adhere strictly to this exact column layout.

### 5.1 The 14 Required Columns (Mandatory)

These 14 fields must be populated for every valid record. If missing in the raw source, apply the mandatory fallback logic specified below and document the population count in the metadata CSV.

  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  \#       Column Name                  Target Data Type         CEDEN Definition & Constraints                            Fallback / Population Rule if Missing in Source
  -------- ---------------------------- ------------------------ --------------------------------------------------------- ------------------------------------------------------------------------------------------------------------------------------------
  **1**    **`StationCode`**            Character (max 35)       Unique alphanumeric station identifier.                   **Rule 2 applies:** Leave as `""` (empty string) / `NA`. Never synthesize. Flag count in metadata CSV.

  **2**    **`SampleDate`**             Date (`YYYY-MM-DD`)      Calendar date of sample collection.                       Must be parsed from date fields. Format strictly as `YYYY-MM-DD`. If unparseable, flag in metadata CSV.

  **3**    **`ProjectCode`**            Character (max 50)       Official CEDEN/SWAMP project code.                        If missing in row, check `ReadMe` sheet. If still absent, use `"REF_<ref_id>"` (e.g., `"REF_4708"`). Flag in metadata CSV.

  **4**    **`CollectionTime`**         Character (`HH:MM:SS`)   Time of sample collection (24-hr clock).                  If unrecorded in source, assign default `"00:00:00"` per CEDEN guidance. Flag count of defaulted times in metadata CSV.

  **5**    **`CollectionMethodCode`**   Character (CV)           Method of sample collection (e.g., `Water_Grab`).         Infer from matrix/analyte: `Water_Grab` for water chemistry; `Field` for probe measurements; `Sed_Grab` for sediment.

  **6**    **`Replicate`**              Integer / Numeric        Field collection replicate number (usually 1).            If missing, default to `1`. Document default in metadata CSV.

  **7**    **`MatrixName`**             Character (CV)           Sample matrix (e.g., `samplewater`, `sediment`).          Crosswalk source matrix (e.g., `"water"` [→]{.math .inline} `"samplewater"`). If missing, infer from sheet name or analyte type.

  **8**    **`MethodName`**             Character (CV)           Analytical method code or description.                    Crosswalk to CEDEN `MethodLookUp`. If unknown in source, use `"FieldMeasure"` for field probes or `"Unspecified"` and flag.

  **9**    **`AnalyteName`**            Character (CV)           Constituent analyzed (e.g., `Copper`, `pH`).              Crosswalk source name to CEDEN `AnalyteLookUp`. Verbatim retention if unmatched; flag in metadata CSV.

  **10**   **`FractionName`**           Character (CV)           Chemical fraction (e.g., `Total`, `Dissolved`, `None`).   Crosswalk source fraction (`Filtered` [→]{.math .inline} `Dissolved`). Default to `None` for field physical parameters (pH, Temp).

  **11**   **`UnitName`**               Character (CV)           Unit of measurement (e.g., `mg/L`, `ug/L`, `none`).       Crosswalk to CEDEN `UnitLookUp`. Assign `none` for pH. Verbatim retention if unmatched; flag in metadata CSV.

  **12**   **`Result`**                 Numeric (Double)         Numerical measurement value.                              **Rule 4 applies:** Verbatim numeric pass-through. If non-detect (`<0.05`), store `0.05`. Never alter value.

  **13**   **`ResQualCode`**            Character (CV)           Result qualifier code (e.g., `=`, `ND`, `DNQ`, `<`).      Crosswalk source qualifier. Default to `=` for detected numeric results without qualifier; `ND` for non-detects.

  **14**   **`QACode`**                 Character (CV)           Quality assurance flag (e.g., `None`, `J`, `B`).          Crosswalk to CEDEN `QALookUp`. Default to `"None"` when no quality deficiency is indicated. Flag unmatched codes.
  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

### 5.2 Contextual, Administrative & Analytical Columns (Optional / Supplementary)

Populate these fields whenever source data provides corresponding values. If absent in source, store as empty string (`""` / `NA`).

  ----------------------------------------------------------------------------------------------------------------------------------------------------------
  \#        Column Name               Data Type             Source Field Aliases / Notes
  --------- ------------------------- --------------------- ------------------------------------------------------------------------------------------------
  **15**    `ProgramCode`             Character (CV)        `ProgramCode`, `Program`, `Data Source`

  **16**    `ParentProjectCode`       Character             `ParentProjectCode`, `ParentProject`, `Parent Project`

  **17**    `QAPPCode`                Character (CV)        `QAPPCode`, `QAPPName`, `QAPP`

  **18**    `StationName`             Character             `StationName`, `Station Name`, `Site Name`, `site description`

  **19**    `StationDescr`            Character             `StationDescr`, `Station Description`, `Site Description`

  **20**    `TargetLatitude`          Numeric (Double)      `Latitude`, `TargetLatitude`, `ActualLatitude`, `SampleLatitude`, `SampleLatitiude`, `y coord`

  **21**    `TargetLongitude`         Numeric (Double)      `Longitude`, `TargetLongitude`, `ActualLongitude`, `SampleLongitude`, `x coord`

  **22**    `Datum`                   Character (CV)        `Datum`, `datum`, `SampleDatum`, `NAD83`, `WGS84`

  **23**    `RegionalBoardID`         Character / Integer   `RegionalBoardID`, `RegionalBoard`, `Region`, `rb_number` (Values 1 to 9)

  **24**    `WaterBodyType`           Character (CV)        `WaterBodyType`, `Water Body Type`, `SWRCBWatTypeCode`

  **25**    `SampleAgencyCode`        Character (CV)        `SampleAgencyCode`, `SampleAgency`, `AgencyCode`, `Agency`

  **26**    `CollectionDepth`         Numeric (Double)      `CollectionDepth`, `DepthSampleCollection`, `Depth`

  **27**    `UnitCollectionDepth`     Character (CV)        `UnitCollectionDepth`, `DepthUnit` (e.g., `m`, `ft`)

  **28**    `CollectionDeviceCode`    Character (CV)        `CollectionDeviceCode`, `CollectionDeviceName`, `SampleDevice`

  **29**    `PositionWaterColumn`     Character (CV)        `PositionWaterColumn`, `Position`

  **30**    `SampleTypeCode`          Character (CV)        `SampleTypeCode`, `SampleType`, `Sample Type` (e.g., `Grab`, `FieldBLDup_Grab`)

  **31**    `LocationCode`            Character (CV)        `LocationCode`, `LocationName`

  **32**    `LabAgencyCode`           Character (CV)        `LabAgencyCode`, `LabAgencyName`, `AnalyzingAgency`, `Analyzing Lab`

  **33**    `SubmittingAgency`        Character (CV)        `SubmittingAgency`, `Submittee`

  **34**    `LabSubmissionCode`       Character             `LabSubmissionCode`, `SubmissionCode`

  **35**    `LabBatch`                Character             `LabBatch`, `Batch`, `Lab Batch`

  **36**    `LabSampleID`             Character             `LabSampleID`, `Lab Sample ID`, `SampleID`

  **37**    `AnalysisDate`            Date (`YYYY-MM-DD`)   `AnalysisDate`, `Analysis Date`

  **38**    `LabReplicate`            Integer / Numeric     `LabReplicate`, `Lab Replicate`

  **39**    `MDL`                     Numeric (Double)      `MDL`, `MethodDetectionLimit`, `lod`. **Rule 1 applies: empty if missing and not in QAPP.**

  **40**    `RL`                      Numeric (Double)      `RL`, `ReportingLimit`, `loq`, `PQL`. **Rule 1 applies: empty if missing and not in QAPP.**

  **41**    `BatchVerificationCode`   Character (CV)        `BatchVerificationCode`, `BatchVerification`, `BatchQualifier`

  **42**    `ComplianceCode`          Character (CV)        `ComplianceCode`, `ComplianceName`

  **43**    `DilutionFactor`          Numeric (Double)      `DilutionFactor`, `Dilution`

  **44**    `ExpectedValue`           Numeric (Double)      `ExpectedValue`, `Expected Value`

  **45**    `SampleComments`          Character             `SampleComments`, `Sample Comments`, `Field Comments`

  **46**    `LabResultComments`       Character             `LabResultComments`, `ResultComments`, `Lab Comments`, `ResultsComments`

  **47**    `LabBatchComments`        Character             `LabBatchComments`, `BatchComments`

  **48**    `FieldResultComments`     Character             `FieldResultComments`, `Field Result Comments`

  **49**    `TissueName`              Character (CV)        `TissueName`, `TISSUE` (e.g., `Muscle`, `Whole Organism`)

  **50**    `TissuePrep`              Character (CV)        `TissuePrep` (e.g., `Dissected`, `Homogenized`)

  **51**    `CommonName`              Character (CV)        `CommonName`, `COMMON`, `Species Name`

  **52**    `FinalID`                 Character (CV)        `FinalID`, `TaxonomicID`, `Genus`, `Species`

  **53**    `LifeStageName`           Character (CV)        `LifeStageName`, `AGE`

  **54**    `TaxonomicQualifier`      Character             `TaxonomicQualifier`

  **55**    `RefID`                   Character             Reference folder identifier (e.g., `"ref4708"`)

  **56**    `SourceFile`              Character             Relative path to source file

  **57**    `SourceSheet`             Character             Sheet name within source workbook
  ----------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

## 6. Phase 4: Controlled Vocabulary (CV) Acquisition Playbook

### 6.1 Automated Download Protocol

The CEDEN Checker hosts official controlled vocabulary tables downloadable via HTTP GET requests. The executing script must download and cache these tables into `./cv_lookups/` as `.csv` files prior to processing data.

-   **Base Export URL:** `https://ceden.org/CEDEN_Checker/Checker/CEDEN_export_xls.php?table=<TableName>`
-   **Output Format:** Even though the script is named `CEDEN_export_xls.php`, the server returns standard Office OpenXML `.xlsx` files (`Content-Type: application/octet-stream`, PK zip header).
-   **Caching Logic:**
    1.  Check if `./cv_lookups/<TableName>.csv` already exists.
    2.  If missing, download from the URL using a timeout threshold of 180 seconds to a temporary file.
    3.  Parse the downloaded spreadsheet using `readxl::read_excel()`.
    4.  Write the parsed lookup table as a UTF-8 CSV file: `./cv_lookups/<TableName>.csv`.

### 6.2 Priority Lookup Tables Specification

The executing agent must download the following primary lookup tables:

  ------------------------------------------------------------------------------------------------------------------------------------------------------------
  Lookup Table Name          Primary Target Columns Validated                     Key Lookup Fields in Table
  -------------------------- ---------------------------------------------------- ----------------------------------------------------------------------------
  `ResQualLookUp`            `ResQualCode`                                        `ResQualCode`, `ResQualName`

  `QALookUp`                 `QACode`                                             `QACode`, `QAName`

  `MatrixLookUp`             `MatrixName`                                         `MatrixName`, `MatrixDescr`

  `FractionLookUp`           `FractionName`                                       `FractionName`, `FractionDescr`

  `UnitLookUp`               `UnitName`                                           `UnitName`

  `AnalyteLookUp`            `AnalyteName`                                        `AnalyteName`, `AnalyteDescr`, `CASNumber`

  `CollectionMethodLookUp`   `CollectionMethodCode`                               `CollectionMethodCode`, `CollectionMethodName`

  `SampleTypeLookUp`         `SampleTypeCode`                                     `SampleTypeCode`, `SampleTypeDescr`

  `MethodLookUp`             `MethodName`                                         `MethodName`, `MethodDescr`

  `StationLookUp`            `StationCode`, `TargetLatitude`, `TargetLongitude`   `StationCode`, `StationName`, `TargetLatitude`, `TargetLongitude`, `Datum`

  `ProgramLookUp`            `ProgramCode`                                        `ProgramCode`, `ProgramName`

  `ProjectLookUp`            `ProjectCode`                                        `ProjectCode`, `ProjectName`

  `QAPPLookUp`               `QAPPCode`                                           `QAPPCode`, `QAPPName`

  `TissueLookUp`             `TissueName`, `TissuePrep`                           `TissueName`, `TissuePrep`
  ------------------------------------------------------------------------------------------------------------------------------------------------------------

### 6.3 StationLookUp Fallback Handling

`StationLookUp` contains tens of thousands of California stations (\~2.2 MB compressed download). If the HTTP request times out due to server load: 1. Re-attempt download using `curl` with retry parameters: `curl -L --retry 3 --connect-timeout 30 -o ./cv_lookups/StationLookUp.xlsx "<URL>"`. Convert to `./cv_lookups/StationLookUp.csv`. 2. If the CEDEN server remains unreachable, proceed using source-provided coordinates only. Set `station_lookup_status = "offline_fallback"` in the metadata CSV sidecars and flag that station lookup verification was deferred.

------------------------------------------------------------------------

## 7. Phase 5: Source-to-Target Column Mapping Playbook

This section details the exact mapping logic for every source archetype.

### 7.1 Master Column Name Normalization & Typo Dictionary

Before evaluating archetype-specific mappings, cleanse all source column names: 1. Strip leading and trailing whitespace. 2. Remove non-printable / control characters. 3. Apply the following known typo corrections:

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------
  Raw Source Header Variation                               Normalized Header Name                      Notes
  --------------------------------------------------------- ------------------------------------------- -----------------------------------------------------------
  `SampleLatitiude`                                         `TargetLatitude`                            Common typo in CEDEN 2020+ exports (e.g., `ref4708.xlsx`)

  `TargetLatitude`, `ActualLatitude`, `SampleLatitude`      `TargetLatitude`                            Coordinate normalization

  `TargetLongitude`, `ActualLongitude`, `SampleLongitude`   `TargetLongitude`                           Coordinate normalization

  `AnalytewFraction`                                        Split into `AnalyteName` & `FractionName`   Common in `ref2427.xls`

  `ResultQualCode`, `ResQualifier`, `ResultQualifier`       `ResQualCode`                               Qualifier normalization

  `QACodeDescr`, `QA Code`, `QADescription`                 `QACode`                                    QA flag normalization

  `Units`, `Unit`, `UnitCode`                               `UnitName`                                  Unit normalization

  `Matrix`, `MatrixCode`                                    `MatrixName`                                Matrix normalization

  `Method`, `MethodCode`                                    `MethodName`                                Method normalization

  `SampleTime`, `Time`, `Collection Time`                   `CollectionTime`                            Time normalization

  `Date`, `Sample Date`, `CollectionDate`                   `SampleDate`                                Date normalization

  `Station ID`, `Station`, `Site ID`, `SiteNumber`          `StationCode`                               Station code normalization

  `Station Name`, `Site Name`, `SiteDescription`            `StationName`                               Station name normalization
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 7.2 Archetype 1: Modern CEDEN / SWAMP Exports (`WaterSedimentField`, `Water`, `Field`, `Habitat`, `Tissue`, `Benthic`)

These sheets contain standardized 50+ to 80+ columns.

#### Direct Column Mapping:

-   `StationCode` [→]{.math .inline} `StationCode`
-   `SampleDate` [→]{.math .inline} `SampleDate`
-   `CollectionTime` [→]{.math .inline} `CollectionTime`
-   `ProjectCode` [→]{.math .inline} `ProjectCode`
-   `CollectionMethodName` or `CollectionMethodCode` [→]{.math .inline} `CollectionMethodCode`
-   `Replicate` or `CollectionReplicate` [→]{.math .inline} `Replicate`
-   `MatrixName` [→]{.math .inline} `MatrixName`
-   `MethodName` [→]{.math .inline} `MethodName`
-   `AnalyteName` (or `Analyte`) [→]{.math .inline} `AnalyteName`
-   `FractionName` [→]{.math .inline} `FractionName`
-   `UnitName` (or `Unit`) [→]{.math .inline} `UnitName`
-   `Result` [→]{.math .inline} `Result`
-   `ResQualCode` [→]{.math .inline} `ResQualCode`
-   `QACode` [→]{.math .inline} `QACode`
-   `MDL` [→]{.math .inline} `MDL`
-   `RL` [→]{.math .inline} `RL`
-   `Latitude` / `TargetLatitude` / `SampleLatitude` / `SampleLatitiude` [→]{.math .inline} `TargetLatitude`
-   `Longitude` / `TargetLongitude` / `SampleLongitude` [→]{.math .inline} `TargetLongitude`
-   `Datum` / `SampleDatum` [→]{.math .inline} `Datum`
-   `SampleTypeCode` [→]{.math .inline} `SampleTypeCode`
-   `CollectionDepth` [→]{.math .inline} `CollectionDepth`
-   `UnitCollectionDepth` [→]{.math .inline} `UnitCollectionDepth`
-   `LabBatch` [→]{.math .inline} `LabBatch`
-   `LabSampleID` [→]{.math .inline} `LabSampleID`
-   `AnalysisDate` [→]{.math .inline} `AnalysisDate`
-   `LabReplicate` [→]{.math .inline} `LabReplicate`
-   `SampleComments` [→]{.math .inline} `SampleComments`
-   `LabResultComments` [→]{.math .inline} `LabResultComments`

#### Special Handling for Tissue Sheets:

-   Map `CommonName` or `FinalID` [→]{.math .inline} `CommonName`
-   Map `TissueName` [→]{.math .inline} `TissueName`
-   Map `TissuePrep` [→]{.math .inline} `TissuePrep`

#### Special Handling for Habitat Sheets:

-   If `Result` is empty but `VariableResult` is populated, copy `VariableResult` [→]{.math .inline} `Result` if numeric; if categorical, copy to `ResQualCode` or `Observation` and record in comments.

------------------------------------------------------------------------

### 7.3 Archetype 2: CIWQS Regulatory Exports (`CIWQS`)

CIWQS exports (e.g., `ref5180.xlsx`) map identically to Archetype 1: - `WQID` [→]{.math .inline} record in `LabResultComments` as `"CIWQS_WQID: <val>"` - Columns `StationCode` through `ResQualCode` map 1-to-1 with Section 7.2.

------------------------------------------------------------------------

### 7.4 Archetype 3: WQX / Water Quality Portal Exports (`WQX`, `WaterQualityPortal`)

WQX spreadsheets (e.g., `ref5831.xlsx`) use standard National WQX naming: - `MonitoringLocationIdentifier` or `StationCode` [→]{.math .inline} `StationCode` - `ActivityStartDate` or `SampleDate` [→]{.math .inline} `SampleDate` - `ActivityStartTime/Time` or `CollectionTime` [→]{.math .inline} `CollectionTime` - `ProjectIdentifier` or `ProjectCode` [→]{.math .inline} `ProjectCode` - `ActivityMediaName` or `MatrixName` [→]{.math .inline} `MatrixName` - `CharacteristicName` or `AnalyteName` [→]{.math .inline} `AnalyteName` - `ResultSampleFractionText` or `FractionName` [→]{.math .inline} `FractionName` - `ResultMeasureValue` or `Result` [→]{.math .inline} `Result` - `ResultMeasure/MeasureUnitCode` or `UnitName` [→]{.math .inline} `UnitName` - `ResultDetectionConditionText` [→]{.math .inline} Crosswalk to `ResQualCode` (e.g., `"Not Detected"` [→]{.math .inline} `"ND"`) - `DetectionQuantitationLimitMeasure/MeasureValue` [→]{.math .inline} `MDL` or `RL`

------------------------------------------------------------------------

### 7.5 Archetype 4: CCAMP / Legacy Regional Board Formats (`Ccamp_WQ_Data`, `Swamp_WQ_Data`)

Files such as `ref2334.xls` and `ref2335.xls` use CCAMP/SWAMP flat layouts: - `StationCode` [→]{.math .inline} `StationCode` - `SampleDate` [→]{.math .inline} `SampleDate` - `SampleTime` [→]{.math .inline} `CollectionTime` - `ProjectID` [→]{.math .inline} `ProjectCode` - `SampleReplicate` [→]{.math .inline} `Replicate` - `MatrixName` [→]{.math .inline} `MatrixName` - `MethodName` [→]{.math .inline} `MethodName` - `AnalyteName` [→]{.math .inline} `AnalyteName` - `FractionName` [→]{.math .inline} `FractionName` - `Unit` [→]{.math .inline} `UnitName` - `Result` [→]{.math .inline} `Result` - `ResultQualCode` [→]{.math .inline} `ResQualCode` - `QACode` [→]{.math .inline} `QACode` - `MDL` [→]{.math .inline} `MDL` - `RL` [→]{.math .inline} `RL` - `DepthSampleCollection` [→]{.math .inline} `CollectionDepth` - `DepthUnit` [→]{.math .inline} `UnitCollectionDepth` - `SampleTypeCode` [→]{.math .inline} `SampleTypeCode` - `AgencyCode` [→]{.math .inline} `SampleAgencyCode` - `Latitude` / `Longitude`: If values equal `"Not Recorded"`, convert to `NA`.

------------------------------------------------------------------------

### 7.6 Archetype 5: CDPR Pesticide Database (`CDPR_Data`, `ref2966.txt`)

Pesticide monitoring tables from the California Department of Pesticide Regulation (DPR): - `site description` [→]{.math .inline} `StationName` - `StationCode`: Leave blank (`""`) per Rule 2, unless a station lookup dictionary is provided in the study. - `date` [→]{.math .inline} `SampleDate` - `chemical` [→]{.math .inline} `AnalyteName` - `Conc [ug/L]` [→]{.math .inline} `Result` (numeric) - `loq` (Limit of Quantitation) [→]{.math .inline} `RL` - `study_cd` [→]{.math .inline} `ProjectCode` (e.g., `"CDPR_STUDY_<study_cd>"`) - `latitude` [→]{.math .inline} `TargetLatitude` - `longitude` [→]{.math .inline} `TargetLongitude` - **Mandatory Default Mappings for CDPR:** - `UnitName`: `"ug/L"` (explicitly declared in header `Conc [ug/L]`) - `MatrixName`: `"samplewater"` (ambient surface water pesticide runoff) - `FractionName`: `"Total"` - `CollectionMethodCode`: `"Water_Grab"` - `MethodName`: `"EPA 680"` or `"Unspecified"` (flag in metadata CSV) - `ResQualCode`: If `Result == 0` or `Result < loq`, set `ResQualCode = "ND"`, else `"="`.

------------------------------------------------------------------------

### 7.7 Archetype 6: Parameter-Per-Sheet Workbooks (`ref2427.xls`, etc.)

In workbooks like `ref2427.xls`, each worksheet represents a distinct analyte (e.g., sheet `Arsenic`, sheet `Lead`, sheet `E. coli`).

#### Processing Specification:

1.  **Determine Analyte Name:**
    -   Inspect the sheet name (e.g., `"Arsenic"`).
    -   If the sheet contains an `Analyte` or `AnalytewFraction` column, use the column value; otherwise, assign the sheet name as `AnalyteName`.
2.  **Column Mappings within Sheets:**
    -   `StationCode` [→]{.math .inline} `StationCode`
    -   `SampleDate` [→]{.math .inline} `SampleDate`
    -   `SampleTime` [→]{.math .inline} `CollectionTime`
    -   `Result` [→]{.math .inline} `Result`
    -   `Unit` [→]{.math .inline} `UnitName`
    -   `ResQualifier` [→]{.math .inline} `ResQualCode`
    -   `MDL` [→]{.math .inline} `MDL`
    -   `RL` [→]{.math .inline} `RL`
    -   `QACodeDescr` [→]{.math .inline} `QACode`
    -   `MatrixName` [→]{.math .inline} `MatrixName`
    -   `MethodName` [→]{.math .inline} `MethodName`
    -   `ActualLatitude` [→]{.math .inline} `TargetLatitude`
    -   `ActualLongitude` [→]{.math .inline} `TargetLongitude`
    -   `Datum` [→]{.math .inline} `Datum`
    -   `ProjectID` [→]{.math .inline} `ProjectCode`
3.  **Union / Combine:** Append records across all analyte sheets for the reference ID into a unified dataset.

------------------------------------------------------------------------

### 7.8 Archetype 7: Wide Matrix / Station-Per-Sheet Workbooks (`ref2449.xls`, `ref2468.xls`)

#### Pattern A: Fish Tissue Wide Matrix (`ref2468.xls`, sheets `MET_WET`, `ORG_DRY`)

Columns represent individual metals: `AG_W`, `AS_W`, `CD_W`, `CR_W`, `CU_W`, `HG_W`, `NI_W`, `PB_W`, `SE_W`, `ZN_W`. - Base columns: - `STANUM` [→]{.math .inline} `StationCode` - `STANAME` [→]{.math .inline} `StationName` - `CDATE` [→]{.math .inline} `SampleDate` - `COMMON` [→]{.math .inline} `CommonName` - `TISSUE` [→]{.math .inline} `TissueName` (crosswalk: `"FF"` [→]{.math .inline} `"Fish Fillet"`, `"WF"` [→]{.math .inline} `"Whole Fish"`) - **Reshape Algorithm:** Pivot wide columns (`*_W`) longer into key-value pairs: - `AnalyteCode` = Column name (e.g., `"HG_W"`) [→]{.math .inline} Crosswalk to CEDEN name: - `AG_W` [→]{.math .inline} `"Silver"` - `AS_W` [→]{.math .inline} `"Arsenic"` - `CD_W` [→]{.math .inline} `"Cadmium"` - `CR_W` [→]{.math .inline} `"Chromium"` - `CU_W` [→]{.math .inline} `"Copper"` - `HG_W` [→]{.math .inline} `"Mercury"` - `NI_W` [→]{.math .inline} `"Nickel"` - `PB_W` [→]{.math .inline} `"Lead"` - `SE_W` [→]{.math .inline} `"Selenium"` - `ZN_W` [→]{.math .inline} `"Zinc"` - `Result` = Numeric cell value - `MatrixName` = `"tissue"` - `FractionName` = `"Total"` - `UnitName` = `"mg/Kg ww"` (wet weight) for `MET_WET`; `"mg/Kg dw"` (dry weight) for `ORG_DRY`.

#### Pattern B: USGS Station-Per-Sheet (`ref2449.xls`)

Each sheet is named after a USGS station (e.g., `USGS9427520`). - Extract `StationCode` from the sheet name: e.g., `"10259540"` (strip `"USGS"` prefix if alphanumeric). - Columns represent USGS Parameter Codes (P-Codes) or constituent names. - Map row dates [→]{.math .inline} `SampleDate`. - Pivot parameter columns to long format: `AnalyteName` and `Result`.

------------------------------------------------------------------------

### 7.9 Archetype 8: Delimited Continuous / Probe Logger Files (`ref3697.txt`, `ref4503.csv`, `ref6628.csv`)

#### Case 1: Continuous Turbidity Logger (`ref3697.txt`)

-   Line 1: `Title: "FAR.csv"`
-   Line 3: `17042,PST,'WATER, TURBIDITY ( ntu)'`
-   Data lines: `YYYYMMDD,HHMM,Result` (e.g., `20080723,0445,1.50`)
-   **Extraction Rules:**
    -   `StationCode`: `"17042"` (from header line 3)
    -   `AnalyteName`: `"Turbidity"`
    -   `UnitName`: `"NTU"`
    -   `MatrixName`: `"samplewater"`
    -   `FractionName`: `"None"`
    -   `MethodName`: `"FieldMeasure"`
    -   `CollectionMethodCode`: `"Field_Cont"`
    -   `SampleDate`: Parse `20080723` [→]{.math .inline} `"2008-07-23"`
    -   `CollectionTime`: Parse `0445` [→]{.math .inline} `"04:45:00"`
    -   `Result`: `1.50`
    -   `ResQualCode`: `"="`
    -   `QACode`: `"None"`

#### Case 2: Multi-Header Beach Watch CSV (`ref4503.csv`)

-   Rows 1-3 contain study titles and date stamps.
-   Row 4 contains column headers: `Program,ParentProject,Project,StationName,StationCode,SampleDate,CollectionTime...`
-   Skip rows 1-3. Parse using Row 4 headers.
-   Convert sentinel `-88` values in numeric columns (`CollectionDepth`, `MDL`, `RL`) to `NA`.

#### Case 3: Ocean Acidification Cruise Data (`ref6628.csv`)

-   Header row 1 contains cruise coordinates and chemistry variables.
-   Pivot wide chemical parameters (`CTDTEMP_ITS90`, `Salinity_PSS78`, `pH`, `pCO2`, `OmegaAragonite`) to long format.
-   Set `MatrixName = "samplewater"`.
-   Set `StationCode` from `Station_ID`.

------------------------------------------------------------------------

## 8. Phase 6: Data Type Conversion & Field Parsing Logic

### 8.1 SampleDate Parsing Logic

Dates exist in multiple formats: Excel serial numbers (e.g., `38000`), ISO strings (`"2004-01-15"`), US slash dates (`"04/05/2005"`), or compact timestamps (`"20080723"`).

The executing script must apply the following cascade:

1.  **Excel Numeric Date Serial:**
    -   If the raw value is numeric (e.g., [30, 000 ≤ *X* ≤ 60, 000]{.math .inline}): [SampleDate = as.Date(*X*, origin = \"1899-12-30\")]{.math .display}
2.  **Text / Character Date:**
    -   Clean string: remove trailing timestamp components if date-only is desired.
    -   Parse using `lubridate::parse_date_time()` with formats: [orders = *c*(\"Ymd\", \"mdY\", \"dmY\", \"Ymd HMS\", \"mdY HMS\")]{.math .display}
    -   Format output strictly as ISO-8601 Date string: `YYYY-MM-DD`.
3.  **Invalid Date Handling:**
    -   If a date cannot be parsed, leave as `NA` and increment `unparseable_dates_count` in metadata CSV.

------------------------------------------------------------------------

### 8.2 CollectionTime Parsing Logic

CEDEN requires `CollectionTime` as `HH:MM:SS` (24-hour clock).

1.  **Excel DateTime / Time Serial:**
    -   If raw time is an Excel datetime object (e.g., `1899-12-31 07:30:00`), extract the time component: `"07:30:00"`.
    -   If raw time is an Excel fraction of a day ([0 ≤ *X* \< 1]{.math .inline}): [Seconds = round(*X* × 86400)]{.math .display} Format as `HH:MM:SS`.
2.  **Text String Parsing:**
    -   Format `"HH:MM"` [→]{.math .inline} Append `":00"`.
    -   Format `"H:MM:SS AM/PM"` [→]{.math .inline} Convert to 24-hour `HH:MM:SS`.
    -   Format `"HHMM"` (e.g., `"0445"`) [→]{.math .inline} Format as `"04:45:00"`.
3.  **Missing / Unrecorded Time Fallback (Mandatory CEDEN Rule):**
    -   If `CollectionTime` is missing, `NA`, empty, or `"0:00"`:
        -   Assign `"00:00:00"`.
        -   Increment `defaulted_midnight_count` in metadata CSV.

------------------------------------------------------------------------

### 8.3 Numeric Result Extraction & Text Parsing

Raw result columns frequently mix numeric values with strings, qualifiers, or non-detect markers (e.g., `"12.4"`, `"< 0.05"`, `"ND"`, `"DNQ"`, `"0.003 J"`).

The executing script must parse these values using the following logic tree:

    [Raw Result Cell Value]
           │
           ├─ Is Numeric? ─────────────────────────> Result = Number verbatim
           │                                         ResQualCode = "=" (if not set)
           │
           ├─ Matches Pattern "^<\s*([0-9.]+)$"? ───> Result = Extracted Number verbatim
           │                                         ResQualCode = "<" (or "ND")
           │
           ├─ Matches Pattern "^>\s*([0-9.]+)$"? ───> Result = Extracted Number verbatim
           │                                         ResQualCode = ">"
           │
           ├─ Equals "ND", "NON-DETECT", "U"? ─────> Result = NA (or 0 if source specifies 0)
           │                                         ResQualCode = "ND"
           │
           ├─ Matches "([0-9.]+)\s*([a-zA-Z]+)"? ──> Result = Extracted Number verbatim
           │  (e.g., "0.04 J", "1.2 DNQ")            ResQualCode = Extracted Qualifier (J/DNQ)
           │
           └─ Entirely Text / Categorical? ─────────> Result = NA
              (e.g., "Present", "Absent")            ResQualCode = "P" or "A"
                                                     Record text in LabResultComments

**Rule 4 Enforcement:** Never alter or round the extracted numeric result. Pass through with exact floating-point precision into the output CSV.

------------------------------------------------------------------------

### 8.4 Sentinel Value Sanitization

In legacy SWAMP, CCAMP, and agency files, specific negative numbers or string codes represent missing data rather than physical measurements:

-   **Sentinel Numbers:** `-88` (Not Recorded), `-99` (Not Applicable), `-8888`, `-9999`.
-   **Action:**
    -   If `-88` or `-99` appears in `MDL`, `RL`, `CollectionDepth`, or `Result` (where result was not detected):
        -   Replace with `NA` (emitted as empty string `""` in CSV).
        -   Document count of sanitized sentinels in metadata CSV.

------------------------------------------------------------------------

## 9. Phase 7: Controlled Vocabulary (CV) Crosswalk Playbook

Every value in a CV column must be crosswalked to CEDEN's official lookup lists. If a value does not match after applying standard synonym mappings, **retain the original value verbatim** and log it in `_metadata.csv`. **Never guess or invent a CV value.**

### 9.1 `ResQualCode` Crosswalk Table

Valid CEDEN entries in `ResQualLookUp` (16 total codes): `<`, `<=`, `=`, `>`, `>=`, `A`, `DNQ`, `JF`, `NA`, `ND`, `NR`, `NRS`, `NRT`, `NSI`, `P`, `PA`.

  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Raw Source Value / Pattern                                             Target CEDEN `ResQualCode`   CEDEN Official `ResQualName`   Operational Logic / Notes
  ---------------------------------------------------------------------- ---------------------------- ------------------------------ ------------------------------------------
  `=`, `==`, `DETECTED`, `DET`, empty string with valid numeric result   `=`                          Equal To                       Standard quantified detection

  `<`, `<MDL`, `<RL`, `LT`, `LESS THAN`                                  `<`                          Less Than                      Value is below specified detection limit

  `<=`, `LE`                                                             `<=`                         Less than or equal to          Upper bound quantification

  `>`, `GT`, `GREATER THAN`                                              `>`                          Greater Than                   Value exceeds analytical ceiling

  `>=`, `GE`                                                             `>=`                         Greater than or equal to       Lower bound quantification

  `ND`, `U`, `NON-DETECT`, `NOT DETECTED`, `NODET`                       `ND`                         Not Detected                   Analyte not detected

  `DNQ`, `J`, `EST`, `ESTIMATED`, `DETECTED NOT QUANTIFIED`              `DNQ`                        Detected Not Quantifiable      Value between MDL and RL

  `JF`                                                                   `JF`                         Field Estimated                Field measurement estimation

  `P`, `PRESENT`, `YES`, `Y`                                             `P`                          Present                        Qualitative presence

  `A`, `ABSENT`, `NO`, `N`                                               `A`                          Absent                         Qualitative absence

  `PA`                                                                   `PA`                         Present/Absent                 Present/Absent test

  `NR`, `NOT RECORDED`, `-88`                                            `NR`                         Not Recorded                   Information not recorded

  `NA`, `NOT ANALYZED`, `N/A`                                            `NA`                         Not Analyzed                   Sample not analyzed for constituent

  `NSI`                                                                  `NSI`                        No Surviving Individuals       Toxicity endpoint
  -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 9.2 `QACode` Crosswalk Table

Valid entries originate from CEDEN `QALookUp` (376 codes). The default for clean data is `"None"`.

  --------------------------------------------------------------------------------------------------------------------------
  Raw Source QA Value                                        Target CEDEN `QACode`   CEDEN `QAName`
  ---------------------------------------------------------- ----------------------- ---------------------------------------
  empty, `NA`, `NONE`, `None`, `OK`, `PASSED`, `GOOD`, `N`   `None`                  None - No QA Qualifier

  `J`, `EST`                                                 `J`                     Estimated value

  `B`, `BLANK`                                               `B`                     Analyte found in reagent blank

  `H`, `HT`, `EXCEEDED_HT`                                   `H`                     Holding time violation

  `IL`, `SURROGATE`                                          `IL`                    Surrogate recovery outside criteria

  `MDL`                                                      `MDL`                   Detection limit elevated

  Any unmapped alphanumeric QA code                          Keep verbatim           Document in `unmatched_unique_values`
  --------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 9.3 `MatrixName` Crosswalk Table

Valid entries originate from CEDEN `MatrixLookUp`. In CEDEN, ambient surface water is strictly `"samplewater"`.

  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Raw Source Matrix Value                                                                                                                    Target CEDEN `MatrixName`   Notes
  ------------------------------------------------------------------------------------------------------------------------------------------ --------------------------- --------------------------------------
  `water`, `Water`, `WATER`, `surface water`, `Surface Water`, `Freshwater`, `Stream`, `River`, `Estuary`, `Marine Water`, `Ambient Water`   `samplewater`               Ambient surface water

  `sediment`, `Sediment`, `SEDIMENT`, `Stream Sediment`, `Bed Sediment`                                                                      `sediment`                  Solid mineral / organic bed material

  `tissue`, `Tissue`, `Fish`, `Fish Tissue`, `Muscle`, `Whole Fish`, `Bivalve`                                                               `tissue`                    Biological tissue

  `effluent`, `Effluent`, `Wastewater`                                                                                                       `effluent`                  Point-source discharge

  `stormwater`, `Stormwater`, `Storm Water`, `Runoff`                                                                                        `stormwater`                Urban / agricultural runoff

  `groundwater`, `Groundwater`, `Well Water`                                                                                                 `groundwater`               Subsurface water

  `porewater`, `Porewater`, `Interstitial Water`                                                                                             `porewater`                 Sediment porewater

  `blankwater`, `DI Water`, `Field Blank`                                                                                                    `blankwater`                Quality control blank

  `habitat`, `Habitat`                                                                                                                       `habitat`                   Physical habitat measurements

  `benthic`, `Benthic`                                                                                                                       `benthic`                   Benthic macroinvertebrates
  -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 9.4 `FractionName` Crosswalk Table

Valid entries originate from CEDEN `FractionLookUp`.

  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Raw Source Fraction Value                                                     Target CEDEN `FractionName`   Notes
  ----------------------------------------------------------------------------- ----------------------------- ---------------------------------------------------------
  `Filtered`, `filter`, `Dissolved`, `DIS`, `Diss`, `D`, `Soluble`              `Dissolved`                   Material passing filter ([ ≤ 0.45 *μ*m]{.math .inline})

  `Unfiltered`, `Total`, `TOT`, `Total Recoverable`, `Whole`, `T`, `Tot`        `Total`                       Whole quantity, unfiltered digestion

  `None`, `NONE`, `NA`, `N/A`, `Not Applicable`, `-88`                          `None`                        Non-fractionated parameters

  Any field physical parameter (pH, Temperature, Conductivity, Turbidity, DO)   `None`                        Automatically assign `None` if blank
  ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 9.5 `UnitName` Crosswalk Table

Valid entries originate from CEDEN `UnitLookUp` (176 units).

  -------------------------------------------------------------------------------------------------------------------------------------------
  Raw Source Unit Value                                             Target CEDEN `UnitName`   Notes
  ----------------------------------------------------------------- ------------------------- -----------------------------------------------
  `mg/l`, `mg/L`, `MG/L`, `ppm` (in water)                          `mg/L`                    Milligrams per liter

  `ug/l`, `ug/L`, `UG/L`, `ppb` (in water), `mcg/L`                 `ug/L`                    Micrograms per liter

  `ng/l`, `ng/L`, `NG/L`, `ppt` (in water)                          `ng/L`                    Nanograms per liter

  `pg/l`, `pg/L`                                                    `pg/L`                    Picograms per liter

  `mg/kg`, `mg/Kg`, `mg/kg dw`                                      `mg/Kg dw`                Milligrams per kilogram dry weight

  `mg/kg ww`, `mg/Kg ww`                                            `mg/Kg ww`                Milligrams per kilogram wet weight

  `ug/kg`, `ug/Kg`, `ug/kg dw`                                      `ug/Kg dw`                Micrograms per kilogram dry weight

  `ug/kg ww`, `ug/Kg ww`                                            `ug/Kg ww`                Micrograms per kilogram wet weight

  `pH`, `pH units`, `std units`, `SU`, `Standard Units`, `units`    `none`                    **Critical CEDEN rule: pH unit is `none`**

  `Deg C`, `deg C`, `Deg. C`, `C`, `Celsius`, `degrees C`, `TEMP`   `Deg C`                   Degrees Celsius (Capital D, space, Capital C)

  `uS/cm`, `us/cm`, `umhos/cm`, `uS/cm @ 25C`, `EC`                 `uS/cm`                   MicroSiemens per centimeter

  `mS/cm`, `ms/cm`                                                  `mS/cm`                   MilliSiemens per centimeter

  `NTU`, `ntu`                                                      `NTU`                     Nephelometric Turbidity Units

  `FNU`                                                             `FNU`                     Formazin Nephelometric Units

  `MPN/100ml`, `MPN/100 mL`, `mpn/100ml`, `MPN/100mL`               `MPN/100 mL`              Most Probable Number per 100 mL

  `CFU/100ml`, `CFU/100 mL`, `cfu/100ml`, `CFU/100mL`               `CFU/100 mL`              Colony Forming Units per 100 mL

  `%`, `percent`, `Percent`, `% Saturation`                         `%`                       Percentage

  `cfs`, `CFS`, `ft3/s`                                             `cfs`                     Cubic feet per second (discharge)

  `m3/s`, `cms`                                                     `m3/s`                    Cubic meters per second

  `m`, `meters`                                                     `m`                       Meters

  `ft`, `feet`                                                      `ft`                      Feet

  `none`, `None`, `dimensionless`                                   `none`                    Dimensionless
  -------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 9.6 `AnalyteName` Crosswalk Table

Valid entries originate from CEDEN `AnalyteLookUp` (4,795 analytes).

  ---------------------------------------------------------------------------------------------------------------------
  Raw Source Analyte String                                                         Target CEDEN `AnalyteName`
  --------------------------------------------------------------------------------- -----------------------------------
  `E. coli`, `Escherichia coli`, `E.coli`, `EC`                                     `Escherichia coli`

  `Enterococcus`, `Enterococci`, `ENT`                                              `Enterococcus`

  `Fecal Coliform`, `Fecal Coliforms`, `FC`                                         `Fecal coliform`

  `Total Coliform`, `Total Coliforms`, `TC`                                         `Total coliform`

  `Water Temperature`, `Temperature, water`, `Temp`, `Water Temp`, `Temperature`    `Temperature`

  `Dissolved Oxygen`, `DO`, `D.O.`, `Oxygen, Dissolved`                             `Oxygen, Dissolved`

  `pH`, `PH`                                                                        `pH`

  `Specific Conductance`, `Conductivity`, `EC`, `Specific Conductivity`, `SpCond`   `SpecificConductivity`

  `Turbidity`, `TURB`                                                               `Turbidity`

  `Total Dissolved Solids`, `TDS`                                                   `Total Dissolved Solids`

  `Total Suspended Solids`, `TSS`                                                   `Total Suspended Solids`

  `Salinity`, `SAL`                                                                 `Salinity`

  `Hardness`, `Hardness as CaCO3`                                                   `Hardness as CaCO3`

  `Ammonia as N`, `Ammonia`, `NH3-N`, `Ammonia-N`                                   `Ammonia as N`

  `Nitrate as N`, `NO3-N`, `Nitrate-N`                                              `Nitrate as N`

  `Nitrite as N`, `NO2-N`, `Nitrite-N`                                              `Nitrite as N`

  `Nitrate + Nitrite as N`, `NO3+NO2 as N`, `Nitrate+Nitrite`                       `Nitrate + Nitrite as N`

  `Total Nitrogen`, `TN`, `Nitrogen, Total`                                         `Nitrogen, Total`

  `Total Phosphorus`, `TP`, `Phosphorus, Total`                                     `Phosphorus as P`

  `Orthophosphate as P`, `Ortho-P`, `PO4-P`, `Orthophosphate`                       `Orthophosphate as P`

  `Sulfate`, `SO4`                                                                  `Sulfate`

  `Chloride`, `Cl`                                                                  `Chloride`

  `Arsenic`, `As`                                                                   `Arsenic`

  `Cadmium`, `Cd`                                                                   `Cadmium`

  `Chromium`, `Cr`                                                                  `Chromium`

  `Copper`, `Cu`                                                                    `Copper`

  `Lead`, `Pb`                                                                      `Lead`

  `Mercury`, `Hg`                                                                   `Mercury`

  `Nickel`, `Ni`                                                                    `Nickel`

  `Selenium`, `Se`                                                                  `Selenium`

  `Silver`, `Ag`                                                                    `Silver`

  `Zinc`, `Zn`                                                                      `Zinc`

  `Diazinon`                                                                        `Diazinon`

  `Chlorpyrifos`                                                                    `Chlorpyrifos`

  `Malathion`                                                                       `Malathion`
  ---------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 9.7 `CollectionMethodCode` Crosswalk Table

Valid entries originate from CEDEN `CollectionMethodLookUp`.

  ------------------------------------------------------------------------------------------------------------------
  Raw Source Collection Method                                                 Target CEDEN `CollectionMethodCode`
  ---------------------------------------------------------------------------- -------------------------------------
  `Water_Grab`, `Grab`, `Water Grab`, `Dip`, `Bucket`                          `Water_Grab`

  `Sed_Grab`, `Sediment_Grab`, `Sediment Grab`, `Core`                         `Sed_Grab`

  `Field`, `Field Method`, `Field Probe`, `Probe`, `Meter`, `In Situ`          `Field`

  `Field_Cont`, `Continuous`, `Logger`, `Sensor`, `Probe_Cont`                 `Field_Cont`

  `Tissue_Grab`, `Tissue Grab`, `Fish Catch`, `Trawl`, `Gill Net`, `Angling`   `Tissue_Grab`

  `Water_Integrated_Depth`, `Depth Integrated`                                 `Water_Integrated_Depth`

  `Water_Integrated_Horizontal`                                                `Water_Integrated_Horizontal`

  `AutoSampler`, `Autosampler`                                                 `AutoSampler`
  ------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

### 9.8 `MethodName` Crosswalk Table

Valid entries originate from CEDEN `MethodLookUp` (1,211 methods).

  ---------------------------------------------------------------------------------------------------------------------
  Raw Source Method String                                                     Target CEDEN `MethodName`
  ---------------------------------------------------------------------------- ----------------------------------------
  `FieldMeasure`, `Field Measure`, `Field Probe`, `YSI`, `Hydrolab`, `Meter`   `FieldMeasure`

  `FieldObservations`, `Visual Observation`                                    `FieldObservations`

  `EPA 200.8`, `EPA200.8`, `200.8`                                             `EPA 200.8`

  `EPA 200.7`, `EPA200.7`, `200.7`                                             `EPA 200.7`

  `EPA 300.0`, `EPA300.0`, `300.0`                                             `EPA 300.0`

  `EPA 1664A`, `1664A`                                                         `EPA 1664A`

  `SM 4500-H+ B`, `SM 4500 H+`, `4500-H+`                                      `SM 4500-H+ B`

  `SM 2540 D`, `SM 2540D`, `TSS SM 2540 D`                                     `SM 2540 D`

  `SM 2540 C`, `SM 2540C`, `TDS SM 2540 C`                                     `SM 2540 C`

  `SM 9223 B`, `Colilert`, `Colilert-18`                                       `SM 9223 B`

  `Enterolert`                                                                 `Enterolert`

  If completely unrecorded in source or QAPP                                   `"Unspecified"` (flag in metadata CSV)
  ---------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------

## 10. Phase 8: Critical Non-Negotiable Rules Playbook

This section details the exact step-by-step enforcement of the non-negotiable rules.

### 10.1 Enforcement of Rule 1: Zero Guessing of Missing MDL / RL

    [Row has missing MDL or RL in raw data]
                         │
                         ▼
           Check if Reference ID has an associated
           QAPP or QA document in ./refs/ or ./refs_extracted/
                         │
             ┌───────────┴───────────┐
             │ YES                   │ NO
             ▼                       ▼
    Scan QAPP document for      Leave MDL = NA (empty string in CSV)
    Detection Limit Table       Leave RL = NA (empty string in CSV)
             │                  Set rule_1_mdl_rl_provenance = "missing_in_source_and_qapp"
             │                  Flag in _metadata.csv
       ┌─────┴─────┐
       │ Found?    │ Not Found?
       ▼           ▼
    Extract exact   Leave MDL = NA, RL = NA
    MDL / RL value  Set rule_1_mdl_rl_provenance = "qapp_scanned_no_match"
    Populate row    Flag in _metadata.csv
    Set rule_1_mdl_rl_provenance = "extracted_from_qapp"

1.  **Detection Limit Extraction Criteria:** An MDL/RL extracted from a QAPP may be applied **only if** the QAPP table explicitly matches both the `AnalyteName` and `MethodName`.
2.  **Ambiguity Rule:** If the QAPP lists multiple project phases with different detection limits, or if the method does not match, **do not guess**. Assign `NA` and document the ambiguity in `_metadata.csv`.

------------------------------------------------------------------------

### 10.2 Enforcement of Rule 2: Zero Synthetic Station Codes

1.  If `StationCode` in the raw data is `NA`, empty string, `"Not Recorded"`, or whitespace:
    -   Assign `StationCode = ""` (empty string in CSV).
    -   **Do NOT execute string concatenation** (e.g., do not do `paste0("STATION_", row_id)`).
    -   Increment `blank_station_codes_count` in metadata CSV.
    -   Confirm `synthetic_station_codes_created = 0`.

------------------------------------------------------------------------

### 10.3 Enforcement of Rule 3: Zero Coordinate Approximation

1.  **Coordinate Verification Cascade:**
    -   Step 1: Check source data columns (`TargetLatitude`, `TargetLongitude`). If valid decimal numbers (Latitude [32.0 ≤ Lat ≤ 42.5]{.math .inline}; Longitude [−125.0 ≤ Long ≤ −114.0]{.math .inline}), retain source coordinates. Set `coordinates_from_source` counter.
    -   Step 2: If coordinates are missing from source data, query CEDEN `StationLookUp` using an exact match on `StationCode`.
        -   If matched in `StationLookUp`: Copy `TargetLatitude`, `TargetLongitude`, and `Datum`. Increment `coordinates_from_station_lookup`.
        -   If unmatched in `StationLookUp`: Set `TargetLatitude = ""`, `TargetLongitude = ""`, `Datum = ""`. Increment `coordinates_missing_count`.
2.  **Strict Prohibition:**
    -   **Never approximate, geocode by city/county, or compute geometric waterbody centroids.**
    -   Set `approximations_made = 0` in metadata CSV.

------------------------------------------------------------------------

### 10.4 Enforcement of Rule 4: Zero Alteration of Numeric Results

1.  Pass the numeric result through directly to the output column `Result`.
2.  Do not round numbers (e.g., do not round `0.04567` to `0.046`).
3.  Set `altered_numeric_results_count = 0` in metadata CSV.

------------------------------------------------------------------------

### 10.5 Enforcement of Rule 5: Strict Row Dropping Criterion

1.  A row is dropped if and only if: [is.na(StationCode) ∧ is.na(AnalyteName) ∧ is.na(Result)]{.math .display}
2.  If a row contains `StationCode = ""` (or `NA`), but has `AnalyteName = "Lead"` and `Result = 4.2`:
    -   **RETAIN THE ROW.**
    -   Do not drop.
3.  Every dropped row must be counted in `rows_dropped_unparseable`.

------------------------------------------------------------------------

## 11. Phase 9: Output Serialization (.csv) & Metadata Sidecar (.csv) Specification

Both the reformatted datasets and their metadata sidecars must be emitted strictly as standard Comma-Separated Values (`.csv`) files.

### 11.1 File Naming & Format Convention

For every processed sheet or table, write two CSV files into `./output/`:

1.  **Reformatted Data CSV (`.csv`):**
    -   Save via R: `readr::write_csv(x = df_ceden, file = output_csv_path, na = "")` or `data.table::fwrite(df_ceden, output_csv_path, na = "")`.
    -   File naming template: [output/ref⟨ID⟩\_⟨sheet_or_table_name⟩.csv]{.math .display} Example: `output/ref4708_WaterSedimentField.csv` If sub-files exist in archives: `output/ref4448_ShastaTailwater_WaterChem.csv`
    -   Specifications:
        -   Comma-delimited (`,`), UTF-8 encoded.
        -   Strings containing commas, quotes, or newlines must be enclosed in double quotes (`"`). Embedded double quotes escaped as `""`.
        -   Dates formatted strictly as `YYYY-MM-DD`.
        -   Times formatted strictly as `HH:MM:SS`.
        -   Missing / null values represented as empty strings (`""`), never literal `"NA"`, `"-88"`, or `"NULL"`.
        -   Floating point numbers emitted without truncation or artificial scientific notation.
2.  **Metadata Sidecar CSV (`_metadata.csv`):**
    -   Save via R: `readr::write_csv(x = metadata_df, file = output_metadata_csv_path, na = "")`.
    -   File naming template: [output/ref⟨ID⟩\_⟨sheet_or_table_name⟩\_*metadata*.csv]{.math .display} Example: `output/ref4708_WaterSedimentField_metadata.csv`
    -   Schema structure: A standardized 4-column Entity-Attribute-Value (EAV) table: [Columns: Section, Property, Value, Notes]{.math .display}

------------------------------------------------------------------------

### 11.2 Complete Sidecar CSV Schema Specification

The metadata CSV captures the complete operational record across seven defined sections:

  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Column Name             Data Type               Description
  ----------------------- ----------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------
  **`Section`**           Character               High-level metadata category (`DatasetSummary`, `RowSummary`, `ColumnMapping`, `RequiredFieldStatus`, `CVValidation`, `DataIntegrity`, `UnresolvedFlag`)

  **`Property`**          Character               Attribute, field name, metric name, or flag ID

  **`Value`**             Character               Count, status string, percentage, or mapped value

  **`Notes`**             Character               Detailed commentary, unmapped column lists, unmatched unique values, provenance records
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#### Section Definitions & Allowed Properties:

1.  **`DatasetSummary`:**
    -   Properties: `dataset_id`, `reference_id`, `source_file`, `source_archive`, `source_sheet`, `output_file`, `output_metadata_file`, `reformatting_timestamp`.
2.  **`RowSummary`:**
    -   Properties: `raw_rows_read`, `rows_dropped_unparseable`, `output_rows`, `drop_reason`.
3.  **`ColumnMapping`:**
    -   Properties: One row for each target CEDEN column mapped.
    -   `Property` = Target CEDEN Column Name (e.g., `StationCode`, `SampleDate`, `TargetLatitude`).
    -   `Value` = Source Column Name (e.g., `StationCode`, `SampleDate`, `SampleLatitiude`).
    -   `Notes` = Mapping type (`direct`, `typo_corrected`, `coerced`, `defaulted`).
    -   Also includes property `unmapped_source_columns` listing unused columns in `Notes`.
4.  **`RequiredFieldStatus`:**
    -   Properties: One row for each of the 14 mandatory fields (`StationCode`, `SampleDate`, `ProjectCode`, `CollectionTime`, `CollectionMethodCode`, `Replicate`, `MatrixName`, `MethodName`, `AnalyteName`, `FractionName`, `UnitName`, `Result`, `ResQualCode`, `QACode`).
    -   `Value` = Populated record count.
    -   `Notes` = Missing record count, defaulted values count (e.g., midnight defaults for time).
5.  **`CVValidation`:**
    -   Properties: One row for each validated CV column (`AnalyteName`, `MatrixName`, `FractionName`, `UnitName`, `MethodName`, `CollectionMethodCode`, `SampleTypeCode`, `ResQualCode`, `QACode`).
    -   `Value` = Count of successfully matched records.
    -   `Notes` = Count of unmatched records and list of distinct unmatched values.
6.  **`DataIntegrity`:**
    -   Properties:
        -   `rule_1_mdl_rl_provenance`: Value = `present_in_source`, `extracted_from_qapp`, or `missing_in_source_and_qapp`. Notes = MDL/RL counts.
        -   `rule_2_synthetic_station_codes`: Value = `0` (Must always be 0). Notes = blank station code count.
        -   `rule_3_coordinate_approximations`: Value = `0` (Must always be 0). Notes = source vs lookup breakdown.
        -   `rule_4_altered_numeric_results`: Value = `0` (Must always be 0). Notes = precision confirmation.
7.  **`UnresolvedFlag`:**
    -   Properties: Sequential flag IDs (`flag_1`, `flag_2`, ...).
    -   `Value` = Warning / Issue Summary.
    -   `Notes` = Detailed context and affected record count.

------------------------------------------------------------------------

### 11.3 Canonical Example of Complete `_metadata.csv`

The following represents the exact CSV content to be written for `output/ref4708_WaterSedimentField_metadata.csv`:

``` csv
Section,             Property,                         Value,                                          Notes
DatasetSummary,      dataset_id,                       ref4708_WaterSedimentField,
DatasetSummary,      reference_id,                     ref4708,
DatasetSummary,      source_file,                      refs/ref4708.xlsx,
DatasetSummary,      source_archive,                   ,                                               Standalone spreadsheet (no parent archive)
DatasetSummary,      source_sheet,                     WaterSedimentField,
DatasetSummary,      output_file,                      output/ref4708_WaterSedimentField.csv,
DatasetSummary,      output_metadata_file,             output/ref4708_WaterSedimentField_metadata.csv,
DatasetSummary,      reformatting_timestamp,           2026-09-06T12:00:00Z,
RowSummary,          raw_rows_read,                    1542,                                           Loaded rows following header detection
RowSummary,          rows_dropped_unparseable,         5,                                              Dropped strictly under Rule 5 (StationCode AnalyteName and Result all NA)
RowSummary,          output_rows,                      1537,                                           Clean records written to output CSV
ColumnMapping,       mapped_columns_count,             52,                                             Total columns mapped to CEDEN target schema
ColumnMapping,       unmapped_source_columns,          "FieldWater, IR_REGIONALBOARD",                 Unmapped columns omitted from output CSV
ColumnMapping,       StationCode,                      StationCode,                                    Direct 1-to-1 mapping
ColumnMapping,       SampleDate,                       SampleDate,                                     Parsed to ISO-8601 Date (YYYY-MM-DD)
ColumnMapping,       CollectionTime,                   CollectionTime,                                 Parsed to 24-hr time (HH:MM:SS)
ColumnMapping,       ProjectCode,                      ProjectCode,                                    Direct 1-to-1 mapping
ColumnMapping,       CollectionMethodCode,             CollectionMethodName,                           Mapped from CollectionMethodName
ColumnMapping,       Replicate,                        Replicate,                                      Direct 1-to-1 mapping
ColumnMapping,       MatrixName,                       MatrixName,                                     Direct 1-to-1 mapping
ColumnMapping,       MethodName,                       MethodName,                                     Direct 1-to-1 mapping
ColumnMapping,       AnalyteName,                      AnalyteName,                                    Direct 1-to-1 mapping
ColumnMapping,       FractionName,                     FractionName,                                   Direct 1-to-1 mapping
ColumnMapping,       UnitName,                         UnitName,                                       Direct 1-to-1 mapping
ColumnMapping,       Result,                           Result,                                         Verbatim numeric pass-through
ColumnMapping,       ResQualCode,                      ResQualCode,                                    Direct 1-to-1 mapping
ColumnMapping,       QACode,                           QACode,                                         Direct 1-to-1 mapping
ColumnMapping,       MDL,                              MDL,                                            Direct 1-to-1 mapping
ColumnMapping,       RL,                               RL,                                             Direct 1-to-1 mapping
ColumnMapping,       TargetLatitude,                   SampleLatitiude,                                Corrected source typo 'SampleLatitiude' to TargetLatitude
ColumnMapping,       TargetLongitude,                  SampleLongitude,                                Mapped to TargetLongitude
ColumnMapping,       Datum,                            SampleDatum,                                    Mapped to Datum
RequiredFieldStatus, StationCode,                      1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, SampleDate,                       1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, ProjectCode,                      1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, CollectionTime,                   1537,                                           Populated: 1537; Defaulted to 00:00:00: 12
RequiredFieldStatus, CollectionMethodCode,             1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, Replicate,                        1537,                                           Populated: 1537; Defaulted to 1: 0
RequiredFieldStatus, MatrixName,                       1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, MethodName,                       1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, AnalyteName,                      1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, FractionName,                     1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, UnitName,                         1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, Result,                           1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, ResQualCode,                      1537,                                           Populated: 1537; Missing: 0
RequiredFieldStatus, QACode,                           1537,                                           Populated: 1537; Missing: 0
CVValidation,        AnalyteName,                      1530,                                           "Matched: 1530; Unmatched: 7; Unmatched values: ['Custom Pesticide Mix A']"
CVValidation,        MatrixName,                       1537,                                           Matched: 1537; Unmatched: 0
CVValidation,        FractionName,                     1537,                                           Matched: 1537; Unmatched: 0
CVValidation,        UnitName,                         1535,                                           "Matched: 1535; Unmatched: 2; Unmatched values: ['unknown_unit']"
CVValidation,        MethodName,                       1520,                                           "Matched: 1520; Unmatched: 17; Unmatched values: ['Lab In-House Method 4B']"
CVValidation,        CollectionMethodCode,             1537,                                           Matched: 1537; Unmatched: 0
CVValidation,        SampleTypeCode,                   1537,                                           Matched: 1537; Unmatched: 0
CVValidation,        ResQualCode,                      1537,                                           Matched: 1537; Unmatched: 0
CVValidation,        QACode,                           1537,                                           Matched: 1537; Unmatched: 0
DataIntegrity,       rule_1_mdl_rl_provenance,         present_in_source,                              "MDL populated: 1500; MDL missing: 37; RL populated: 1500; RL missing: 37; Missing left as NA per Rule 1"
DataIntegrity,       rule_2_synthetic_station_codes,   0,                                              Verified: 0 synthetic station codes created; Blank station codes: 0
DataIntegrity,       rule_3_coordinate_approximations, 0,                                              "Verified: 0 approximations made; From source: 1537; From lookup: 0; Missing: 0"
DataIntegrity,       rule_4_altered_numeric_results,   0,                                              Verified: 0 numeric results altered; Precision preserved verbatim
UnresolvedFlag,      flag_1,                           7 records with unmatched AnalyteName,           Unmatched constituent: 'Custom Pesticide Mix A'
UnresolvedFlag,      flag_2,                           37 records missing MDL and RL,                  Left as NA per Rule 1 (not present in source or QAPP)
```

------------------------------------------------------------------------

## 12. Phase 10: Automated Quality Assurance & Verification Playbook

Before any dataset is declared complete, the executing script must run the following assertion tests on the emitted CSV files:

### 12.1 Programmatic Assertions Checklist

1.  **Output File Existence & Non-Zero Size:**
    -   Verify `file.exists("output/<dataset_id>.csv")` and `file.info("output/<dataset_id>.csv")$size > 0`.
    -   Verify `file.exists("output/<dataset_id>_metadata.csv")` and `file.info("output/<dataset_id>_metadata.csv")$size > 0`.
2.  **Row Count Conservation:**
    -   Read the output CSV row count ([*N*~out~]{.math .inline}).
    -   Assert: [raw_rows_read =  = *N*~out~ + rows_dropped_unparseable]{.math .display}
    -   If false, halt with an accounting error.
3.  **Required Columns Check:** Verify that all 14 required columns exist as column headers in `output/<dataset_id>.csv`: [{\"StationCode\", \"SampleDate\", ..., \"QACode\"} ⊆ names(read_csv(..., n_max = 1))]{.math .display}
4.  **Data Type & Format Verifications in CSV:**
    -   `SampleDate`: Every non-empty cell must match regex `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`.
    -   `CollectionTime`: Every non-empty cell must match regex `^[0-9]{2}:[0-9]{2}:[0-9]{2}$`.
    -   `Result`: Every non-empty cell must parse as a valid numeric double (`!is.na(as.numeric(Result))`).
    -   `Replicate`: Every non-empty cell must parse as a valid integer (`as.integer(Replicate)`).
5.  **Coordinate Bounding Box Check:** For all non-empty coordinates in the output CSV: [32.0 ≤ as.numeric(*TargetLatitude*) ≤ 42.5  ∧   − 125.0 ≤ as.numeric(*TargetLongitude*) ≤ −114.0]{.math .display} Any coordinates falling outside this boundary must be logged as a flag in the metadata CSV.
6.  **Rule Integrity Assertions:**
    -   Confirm `synthetic_station_codes_created == 0`.
    -   Confirm `approximations_made == 0`.
    -   Confirm `altered_numeric_results_count == 0`.
7.  **Sidecar Metadata CSV Validation:**
    -   Verify that `output/<dataset_id>_metadata.csv` parses cleanly with `readr::read_csv()`.
    -   Verify all four columns exist: `Section`, `Property`, `Value`, `Notes`.
    -   Verify sections `DatasetSummary`, `RowSummary`, `ColumnMapping`, `RequiredFieldStatus`, `CVValidation`, and `DataIntegrity` are all present.

------------------------------------------------------------------------

## 13. Phase 11: End-to-End Batch Execution Playbook

This numbered section specifies the exact operational order of execution for the future agent.

### 13.1 Sequential Step-by-Step Execution Plan

    Step 1: Environment Initialization & Directory Creation
       │
       ▼
    Step 2: Controlled Vocabulary (CV) Caching (Download -> ./cv_lookups/*.csv)
       │
       ▼
    Step 3: Recursive Archive Extraction (refs/*.zip -> refs_extracted/)
       │
       ▼
    Step 4: Source Dataset Discovery & Archetype Classification
       │
       ▼
    Step 5: Reference Processing Loop (For each Ref ID):
       │   ├── 5.1 Locate all data workbooks/sheets for Ref ID
       │   ├── 5.2 Header detection & leading metadata stripping
       │   ├── 5.3 Apply Rule 5 summary row dropping
       │   ├── 5.4 Column name normalization & dictionary mapping
       │   ├── 5.5 Reshape wide tables (Archetypes 6, 7, 8) if applicable
       │   ├── 5.6 Data type parsing (SampleDate -> YYYY-MM-DD, CollectionTime -> HH:MM:SS, Result)
       │   ├── 5.7 CV crosswalk & synonym normalization
       │   ├── 5.8 Rule 1 (MDL/RL), Rule 2 (Station), Rule 3 (Coordinates) enforcement
       │   ├── 5.9 Run Phase 10 verification assertions
       │   ├── 5.10 Serialize reformatted data to ./output/<dataset_id>.csv
       │   └── 5.11 Emit sidecar metadata to ./output/<dataset_id>_metadata.csv
       │
       ▼
    Step 6: Batch Summary Report Generation (output/BATCH_SUMMARY_REPORT.csv)

### 13.2 Detailed Step Instructions

1.  **Step 1: Environment Initialization:**
    -   Create directories `./refs_extracted/`, `./cv_lookups/`, `./output/`, and `./logs/`.
    -   Verify all required R packages (`readxl`, `readr`, `data.table`, `dplyr`, `tidyr`, `lubridate`, `stringr`, `purrr`, `foreign`) load without warnings.
2.  **Step 2: Controlled Vocabulary Caching:**
    -   Loop through the priority lookup tables specified in Section 6.2.
    -   Download missing tables from CEDEN Checker and save as UTF-8 CSV: `./cv_lookups/<TableName>.csv`.
3.  **Step 3: Recursive Archive Extraction:**
    -   Execute extraction for all `.zip` files in `./refs/` into `./refs_extracted/<ref_id>/`.
    -   Recursively unpack nested `.zip` archives.
    -   Delete `__MACOSX`, `.DS_Store`, and `~$*` lockfiles.
4.  **Step 4: Discovery & Inventory:**
    -   Catalog all standalone files in `./refs/` and extracted files in `./refs_extracted/`.
    -   Classify each file into its archetype (ARCH-1 through ARCH-8, DOC-META, NON-DATA).
    -   Link any QAPP documents (`.pdf`, `.doc`) to their parent Reference ID.
5.  **Step 5: Reformatting Loop (Per Reference File):**
    -   Wrap processing for each dataset in a `tryCatch` block to isolate errors. A single corrupt spreadsheet must not terminate the entire pipeline.
    -   Read sheet data, apply header detection (Section 4.3), and drop summary rows under Rule 5 (Section 4.4).
    -   Apply column mapping dictionary (Section 7).
    -   Parse dates (`YYYY-MM-DD`), times (`HH:MM:SS`), and numeric results (Section 8).
    -   Apply CV crosswalk tables (Section 9).
    -   Check QAPP for missing MDL/RL (Section 10.1).
    -   Run verification assertions (Section 12.1).
    -   Write reformatted data to `output/<dataset_id>.csv` using `readr::write_csv(..., na = "")`.
    -   Write metadata sidecar to `output/<dataset_id>_metadata.csv`.
6.  **Step 6: Batch Summary Reporting:**
    -   Read all emitted `_metadata.csv` files in `./output/`.
    -   Generate a consolidated summary report (`./output/BATCH_SUMMARY_REPORT.csv`):
        -   `dataset_id`
        -   `reference_id`
        -   `raw_rows_read`
        -   `output_rows`
        -   `rows_dropped_unparseable`
        -   `unmatched_cv_count`
        -   `missing_station_codes`
        -   `missing_mdl_rl_count`
        -   `status` (`SUCCESS` or `WARNING`)

------------------------------------------------------------------------

## 14. Troubleshooting & Known Edge-Case Playbook

  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Edge-Case Symptom                                              Root Cause                                                    Mandated Playbook Solution
  -------------------------------------------------------------- ------------------------------------------------------------- -------------------------------------------------------------------------------------------------------------------------------------------------------------------
  **All column names are `...1`, `...2`, `...3`**                Table has leading title rows or metadata block above header   Execute Section 4.3 Header Detection Algorithm. Find row where CEDEN keyword count [ ≥ 3]{.math .inline}. Skip preceding rows.

  **Numeric dates appear as 5-digit integers (e.g., `38405`)**   Excel stored date as internal day serial count                Convert using origin: `as.Date(x, origin = "1899-12-30")`. Format as `YYYY-MM-DD`.

  **CollectionTime is listed as `0` or `1899-12-31 00:00:00`**   Time unrecorded by field sampler                              Assign default `"00:00:00"` per CEDEN standard. Increment `defaulted_midnight_count` in metadata CSV.

  **Result column contains text strings (e.g., `"< 0.005"`)**    Non-detect string embedded in result column                   Parse number `0.005` into `Result`; set `ResQualCode = "<"`. Never drop or alter the number `0.005`.

  **Coordinates appear as positive numbers (e.g., `121.45`)**    Missing negative sign on California West longitudes           California longitudes are strictly negative. If `114.0 <= Long <= 125.0`, multiply by `-1` (`TargetLongitude = -abs(Long)`). Document correction in metadata CSV.

  **Sheet name is `ReadMe` or `Graphs`**                         Non-data workbook sheet                                       Skip sheet for data reformatting. Extract project metadata from `ReadMe` if present.

  **Both `.xlsx` and `.zip` exist for same Ref ID**              S-drive gathered both archive and standalone export           Compare row counts and sheet names. If duplicate, process the most complete file. If distinct sub-studies, process both with unique sub-dataset IDs.

  **Access `.mdb` file in zip archive**                          Legacy MS Access database (e.g., `ref3653.zip`)               Use `RODBC` or `mdb-tools` to dump tables to CSV. If database tools unavailable, catalog in metadata CSV and flag for manual conversion.

  **Analyte is not found in `AnalyteLookUp`**                    Regional synonym or trade name (e.g., `"Diazinon oxon"`)      Retain original text verbatim in `AnalyteName`. Add to `unmatched_unique_values` in `_metadata.csv`. Do not guess or substitute.
  ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
