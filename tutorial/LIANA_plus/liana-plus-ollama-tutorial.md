## LIANA+ With Ollama LLM tutorial
> To obtain input results from the LIANA+ algorithm, please refer to the [LIANA+ documentation](https://liana-py.readthedocs.io/en/latest/notebooks/basic_usage.html) for generation instructions.


## Prerequisites
- Python 3.9
- Conda package manager
- Internet connection for downloading packages and models

## Installation of LLM

### Step 1: Set Up Python Environment
Create and activate a conda environment:

```bash
conda create -n is2c2 python=3.9
conda activate is2c2
```

### Step 2: Install Python Dependencies
Install the required Python packages:

```bash
pip install -q -r requirements.txt
```

### Step 3: Install Ollama
1. Visit the [Ollama official website](https://ollama.com/download)
2. Download the installer for your operating system
3. Follow the installation instructions provided

### Step 4: Verify Ollama Installation
Check if the Ollama server is running properly:

```bash
curl http://localhost:11434
```

You should see `Ollama is running`

Alternatively, you can visit http://localhost:11434 in your browser. If the Ollama server is running properly, the browser will display the following:

![ollama](/screenshots/ollama-success.png)

## Data
The input data utilizes PBMC3k from SeuratData, which is processed through LIANA+ and CellChat algorithms to generate the results used as input. The processed data is available in [Google Drive](https://drive.google.com/file/d/1ZifaMtldX4lvSkB1YrmA_P1V-YPVIAZM/view?usp=sharing).

## Usage
### Step 1: Start Ollama Service
```bash
ollama serve
```

### Step 2: Download Language Model
> If you want to use additional models, please refer to the detailed model information on https://ollama.com/search, download your preferred model using ollama pull <model-name>, and then specify it using the --model parameter in your command.
```bash
ollama pull llama3.2
```
> **Note**: If you have access to advanced computing resources such as high-memory GPUs (H100, A100), we recommend using large-parameter open-source models like GPT-oss 120B, Qwen-72B, and DeepSeek-V3-671B to optimize performance and accuracy.

### Step 3: Run an Example
Make the pipeline executable:

```bash
chmod +x lianaplus-llm.sh
```

Run the analysis with example data using default parameter settings:

```shell
./lianaplus-llm.sh \
--cell-type "Memory CD4 T-CD14+ Mono" \
--disease-context "Peripheral Blood Mononuclear Cells" \
--llm-provider "ollama" \
--model "llama3.2:latest" \
--liana-result "../pbmc-process/PBMC_memory_cd4_to_cd14_mono.csv"
```

Explain about the parameters as follows: 

```shell
./lianaplus-llm.sh \
--cell-type "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
--disease-context "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
--llm-provider "ollama"
--model "(The openmodel pulled from ollama platform)" \
--liana-result "(The path to the CSV file containing significant ligand-receptor interaction data with downstream pathway branches from LIANA+ output)" \

```
* For more detailed information about the parameters, please refer to [parameter-table](../../parameters.md)
* Result will be saved in the default work-directory: /results


## Expected Output
For more details, see the [example report](https://mocha.houstonmethodist.org/iS2C2/ollama-llama32-liana-plus.html).

![example-output](../../screenshots/output/lianaplus/ollama/ollama-lianaplus.png)