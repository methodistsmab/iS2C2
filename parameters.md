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
| `--percent-exp`                  | Expression percentage threshold                                    | float    | 0.005                        |
| `--logfc-threshold`              | Log fold change threshold                                          | float    | 0.20                         |
| `--intermediate-downstream-gene-num` | Intermediate downstream gene number                           | integer  | 2                            |
| `--permutation-num`              | Number of permutations                                             | integer  | 1000                         |
| `--lambda`                       | Lambda parameter                                                   | float    | 0.5                          |
| `--species`                      | Species: mouse or human                                            | string   | mouse                        |
| `--assay`                        | Assay type: RNA or integrated                                      | string   | RNA                          |
| `--disease`                      | Disease context                                                    | string   | AD                           |
| `--results-dir`                  | Results output directory                                           | string   | results                      |
| `--disease-context`              | Disease context for LLM analysis                                   | string   | Alzheimer's disease          |
| `--llm-provider`                 | LLM provider: "ollama" or "gemini"                                | string   | ollama                       |
| `--model`                        | Model name for LLM                                                 | string   | llama3.2 (ollama default)    |
| `--api-key`                      | API key (required for Gemini API)                                  | string   | (none)                       |
| `--temperature`                  | Model temperature for LLM                                          | float    | 0.7                          |
| `--max-tokens`                   | Maximum tokens for LLM generation                                  | integer  | 1500                         |
| `--context-size`                 | Context window size for LLM                                        | integer  | 131072                       |
| `--seed`                         | Random seed for LLM                                                | integer  | 512                          |
| `--algorithm`                    | Algorithm for LLM hypothesis generation                            | string   | s2c2                         |
| `--s2c2-script`                  | Path to S2C2_CLI.R script                                          | string   | S2C2_CLI.R                   |
| `--ollama-script`                | Path to local-ollama.py script                                     | string   | local-ollama-api.py          |
| `--gemini-script`                | Path to gemini-api-call.py script                                  | string   | gemini-api-call.py           |
| `--help`, `-h`                   | Show help message                                                  | flag     | (none)                       |
