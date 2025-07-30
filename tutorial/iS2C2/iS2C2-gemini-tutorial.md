## iS2C2 With Gemini LLM tutorial

This demonstration uses the Gemini API, which supports the following models: gemini-2.0-flash, gemini-2.5-flash, and gemini-2.5-pro. For more information, please refer to: [Gemini API docs](https://ai.google.dev/gemini-api/docs?authuser=1)



### Prepare the API Key
Please navigate to the [Gemini Key website](https://aistudio.google.com/apikey) and create your own Gemini API key.

> Please put your API key in the `.env` file for security purposes.


Put your API key in a .env file as GEMINI_API_KEY="your-gemini-api-key", then run:
```bash
source .env
```
```bash
export TEMP_GEMINI_API_KEY="$GEMINI_API_KEY"
```

check your API Key 
```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY" | head -n 10
```
A successful response should return something like:`{
  "models": [
    {
      ........
    }`

### Running LLM Hypothesis Generation with S2C2
Quick run with the [example data](https://drive.google.com/file/d/1Ejcch9g5_kcj-0iJnIPnU5s9LmlGEUx8/view?usp=share_link)

```bash
./iS2C2.sh \
  --rds-file "./pbmc_control_example_clean_7_21_25" \
  --celltype-colname "seurat_annotations" \
  --condition-colname "condition" \
  --condition1 "control" \
  --condition2 "NA" \
  --sender "Memory CD4 T" \
  --receiver "CD14+ Mono" \
  --species "human" \
  --assay "RNA" \
  --cell-type "astrocyte-excitatory neuron" \
  --disease-context "Alzheimer's disease" \
  --algorithm "s2c2" \
  --llm-provider "gemini" \
  --model "gemini-2.5-pro" \
  --api-key "$TEMP_API_KEY"
```

```bash
./iS2C2.sh \
  --rds-file "example.rds (The Seurat RDS file containing single-cell RNA sequencing data)" \
  --celltype-colname "(The column name in the Seurat object's metadata that contains the cell type annotations)" \
  --condition-colname "(The column name in the Seurat object's metadata that contains the experimental condition or phenotype labels)" \
  --condition1 "(The primary condition value)" \
  --condition2 "(the secondary condition value)" \
  --sender "(Sender cell type)" \
  --receiver "(Receiver cell type)" \
  --species "(The species of the input data)" \
  --assay "(The data slot to use from the Seurat object)" \
  --cell-type "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
  --disease-context "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
  --algorithm "s2c2" \
  --llm-provider "gemini" \
  --model "gemini-2.5-pro" \
  --api-key "$TEMP_GEMINI_API_KEY"
```