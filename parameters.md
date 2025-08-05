# iS2C2.sh Parameters

| Parameter                        | Description                                                        | Type     | Default Value                |
|----------------------------------|--------------------------------------------------------------------|----------|------------------------------|
| `--rds-file`                     | Seurat RDS file path (input data)                                  | string   | (required)                   |
| `--celltype-colname`             | Cell type column name in metadata                                  | string   | (required)                   |
| `--condition-colname`            | Condition column name in metadata                                  | string   | (required)                   |
| `--condition1`                   | Primary condition value                                            | string   | (required)                   |
| `--condition2`                   | Secondary condition value (use 'NA' for none)                      | string   | (required)                   |
| `--sender`                       | Sender cell type                                                   | string   | (required)                   |
| `--receiver`                     | Receiver cell type                                                 | string   | (required)                   |
| `--cell-type`                    | Cell communication type for LLM analysis                           | string   | (required)                   |
| `--disease-context`              | Disease context for LLM analysis                                   | string   | (required)                   |
| `--percent-exp`                  | Expression percentage threshold                                    | float    | 0.005                        |
| `--logfc-threshold`              | Log fold change threshold                                          | float    | 0.20                         |
| `--intermediate-downstream-gene-num` | Intermediate downstream gene number                           | integer  | 2                            |
| `--permutation-num`              | Number of permutations                                             | integer  | 1000                         |
| `--lambda`                       | Lambda parameter                                                   | float    | 0.5                          |
| `--species`                      | Species: mouse or human                                            | string   | mouse                        |
| `--assay`                        | Assay type: RNA or integrated                                      | string   | RNA                          |
| `--llm-provider`                 | LLM provider: "ollama", "gemini", or "openrouter"                 | string   | ollama                       |
| `--model`                        | Model name for LLM                                                 | string   | llama3.2 (ollama default)    |
| `--api-key`                      | API key (required for Gemini and OpenRouter API)                  | string   | (none)                       |
| `--temperature`                  | Model temperature for LLM                                          | float    | 0.4                          |
| `--max-tokens`                   | Maximum tokens for LLM generation                                  | integer  | 100000                       |
| `--context-size`                 | Context window size for LLM                                        | integer  | 131072                       |
| `--seed`                         | Random seed for LLM                                                | integer  | 512                          |
| `--help`, `-h`                   | Show help message                                                  | flag     | (none)                       |

**Note:** Algorithm is fixed to 's2c2' and cannot be modified.

---

# LIANAPlus-llm.sh Parameters

| Parameter                        | Description                                                        | Type     | Default Value                |
|----------------------------------|--------------------------------------------------------------------|----------|------------------------------|
| `--liana-result`                 | LIANA+ result file path (CSV format)                               | string   | (required)                   |
| `--cell-type`                    | Cell communication type for LLM analysis                           | string   | (required)                   |
| `--disease-context`              | Disease context for LLM analysis                                   | string   | (required)                   |
| `--llm-provider`                 | LLM provider: "ollama", "gemini", or "openrouter"                 | string   | ollama                       |
| `--model`                        | Model name for LLM                                                 | string   | llama3.2 (ollama default)    |
| `--api-key`                      | API key (required for Gemini and OpenRouter API)                  | string   | (none)                       |
| `--temperature`                  | Model temperature for LLM                                          | float    | 0.4                          |
| `--max-tokens`                   | Maximum tokens for LLM generation                                  | integer  | 100000                       |
| `--context-size`                 | Context window size for LLM                                        | integer  | 131072                       |
| `--seed`                         | Random seed for LLM                                                | integer  | 512                          |
| `--help`, `-h`                   | Show help message                                                  | flag     | (none)                       |

**Note:** Algorithm is fixed to 'lianaplus' and cannot be modified.

---

# NicheNet-llm.sh Parameters

| Parameter                        | Description                                                        | Type     | Default Value                |
|----------------------------------|--------------------------------------------------------------------|----------|------------------------------|
| `--lr-file`                      | NicheNet LR file path (CSV format)                                 | string   | (required)                   |
| `--lt-file`                      | NicheNet LT file path (CSV format)                                 | string   | (required)                   |
| `--cell-type`                    | Cell communication type for LLM analysis                           | string   | (required)                   |
| `--disease-context`              | Disease context for LLM analysis                                   | string   | (required)                   |
| `--llm-provider`                 | LLM provider: "ollama", "gemini", or "openrouter"                 | string   | ollama                       |
| `--model`                        | Model name for LLM                                                 | string   | llama3.2 (ollama default)    |
| `--api-key`                      | API key (required for Gemini and OpenRouter API)                  | string   | (none)                       |
| `--temperature`                  | Model temperature for LLM                                          | float    | 0.4                          |
| `--max-tokens`                   | Maximum tokens for LLM generation                                  | integer  | 100000                       |
| `--context-size`                 | Context window size for LLM                                        | integer  | 131072                       |
| `--seed`                         | Random seed for LLM                                                | integer  | 512                          |
| `--help`, `-h`                   | Show help message                                                  | flag     | (none)                       |

**Note:** Algorithm is fixed to 'nichenet' and cannot be modified.

---

# Common LLM Configuration Notes

## LLM Provider Default Models
- **Ollama**: `llama3.2` (default)
- **Gemini**: `gemini-2.0-flash` (auto-selected if llama3.2 is specified)
- **OpenRouter**: `openai/gpt-4o` (auto-selected if llama3.2 is specified)

## API Key Requirements
- **Ollama**: No API key required (local)
- **Gemini**: API key required
- **OpenRouter**: API key required

## Algorithm-Specific Input Files
- **S2C2**: Requires Seurat RDS file and metadata columns
- **LIANA+**: Requires LIANA+ result CSV file
- **NicheNet**: Requires both LR.csv and LT.csv files

## Output Directory
All scripts automatically save results to `results/run_YYYYMMDD_HHMMSS/` with timestamped subdirectories.
