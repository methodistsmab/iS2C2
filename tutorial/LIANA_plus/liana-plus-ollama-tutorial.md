## LIANA+ With Ollama LLM tutorial
> To learn more about LIANA+, please refer to the [LIANA+ documentation](https://liana-py.readthedocs.io/en/latest/notebooks/basic_usage.html).


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
The LIANA+ example data are available in [Google Drive](https://drive.google.com/file/d/1ZifaMtldX4lvSkB1YrmA_P1V-YPVIAZM/view?usp=sharing).

**Download the example data** and place it in your working directory before proceeding with the analysis.


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


### Step 3: Run an Example
Run the analysis with example data using default parameter settings:

```python 
python ./local-ollama-api.py \
--cell "Memory CD4 T-CD14+ Mono" \
--disease "Peripheral Blood Mononuclear Cells" \
--model "llama3.2" \
--significant-branches-file "../PBMC_memory_cd4_to_cd14_mono.csv" \
--algorithm "lianaplus" 
```

Explain about the parameters as follows: 

```python 
python ./local-ollama-api.py \
--cell "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
--disease "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
--model "(The openmodel pulled from ollama platform)" \
--significant-branches-file "((The path to the CSV file containing significant ligand-receptor interaction data with downstream pathway branches))" \
--algorithm "liana" 

```
* For more detailed information about the parameters, please refer to [parameter-table](../../parameters.md)
* Result will be saved in the default work-directory: /results


## Expected Output
For more details, see the [example report](../../output/ollama_qwen25_8b_lianaplus/llm_report_ollama_Memory_CD4_T_CD14+_Mono_Peripheral_Blood_Mononuclear_Cells_qwen2514b_lianaplus_20250731_175929.html).

![example-output](../../screenshots/output/lianaplus/ollama/ollama-lianaplus.png)