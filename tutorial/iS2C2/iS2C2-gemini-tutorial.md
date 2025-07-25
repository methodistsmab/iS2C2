## iS2C2 With Gemini LLM tutorial

This demonstration uses the Gemini API, which supports the following models: gemini-2.0-flash, gemini-2.5-flash, and gemini-2.5-pro. For more information, please refer to: [Gemini API docs](https://ai.google.dev/gemini-api/docs?authuser=1)

Please put your API key in the `.env` file for security purposes.


### Prepare the API Key


```python
import os
from dotenv import load_dotenv
load_dotenv()
api_key = os.getenv('GEMINI_API_KEY')
os.environ['TEMP_API_KEY'] = api_key
```

### Running LLM Hypothesis Generation with S2C2


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
  --api-key "$TEMP_API_KEY"
```