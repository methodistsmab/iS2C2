## iS2C2 With OpenAI LLM tutorial

This demonstration uses the OpenAI API via Openrouter platform, which supports the [models](https://openrouter.ai/models).



### Prepare the API Key
Please navigate to the [Openrouter Key website](https://openrouter.ai/settings/keys) and create your own Gemini API key.

>Please put your API key in the `.env` file for security purposes.


Put your API key in a .env file as OPENROUTER_API_KEY="your-openrouter-api-key", then run:
```bash
source .env
```
```bash
export TEMP_OPENROUTER_API_KEY="$OPENROUTER_API_KEY"
```

check your API Key 
```bash
curl https://openrouter.ai/api/v1/credits \
     -H "Authorization: Bearer $TEMP_OPENROUTER_API_KEY"
```
A successful response should return something like: `{"data":{"total_credits":xxx,"total_usage":0.xxxx}}% `

> Also, keep eyes on your credits activity on this site: [key-activity](https://openrouter.ai/activity)

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
  --disease "AD" \
  --cell-type "astrocyte-excitatory neuron" \
  --disease-context "Alzheimer's disease" \
  --model "openai/gpt-4.1-mini" \
  --algorithm "s2c2"
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
  --llm-provider "openrouter" \
  --model "openai/gpt-4.1-mini"  \
  --api-key "$TEMP_OPENROUTER_API_KEY"
```