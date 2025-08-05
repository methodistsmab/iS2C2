## NicheNet With Gemini LLM tutorial
> To obtain input results from the NicheNet algorithm, please refer to the [NicheNet documentation](https://github.com/saeyslab/nichenetr) for generation instructions.

## Prerequisites
- Python 3.9
- Conda package manager
- Internet connection for downloading packages and models


This demonstration uses the Gemini API, which supports the following models: gemini-2.0-flash, gemini-2.5-flash, and gemini-2.5-pro. For more information, please refer to: [Gemini API docs](https://ai.google.dev/gemini-api/docs?authuser=1)

## Installation Dependencies 
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


## Prepare the Gemini API Key
This demonstration uses the Gemini API, which supports the following models: gemini-2.0-flash, gemini-2.5-flash, and gemini-2.5-pro. For more information, please refer to: [Gemini API docs](https://ai.google.dev/gemini-api/docs?authuser=1)

Please navigate to the [Gemini Key website](https://aistudio.google.com/apikey) and create your own Gemini API key.


Refer to this [Gemini-key tutorial](../get-gemini-key.md) for step-by-step instructions on obtaining your Gemini API key.

---

## Data
The input data utilizes PBMC3k from SeuratData, which is processed through NicheNet algorithm to generate the ligand-receptor and ligand-target interaction results used as input. The processed data is available in [Google Drive](https://drive.google.com/drive/folders/1t1Eq2n1H1loCx78nt6CX9thLGUAusFVB?usp=sharing). The original data source is the same RDS file used in the iS2C2 tutorial.

---



## Usage

###  Run an Example

Make the pipeline executable:

```bash
chmod +x nichenet-llm.sh
```

Quick run the analysis with example data using default parameter settings:

```bash
./nichenet-llm.sh \
--cell-type "Memory CD4 T-CD14+ Mono" \
--disease-context "Peripheral Blood Mononuclear Cells" \
--llm-provider "gemini" \
--model "gemini-2.5-pro" \
--lr-file "../NicheNet/From_Memory CD4 T_To_CD14+ Mono_LR.csv" \
--lt-file "../NicheNet/From_Memory CD4 T_To_CD14+ Mono_LT.csv" \
--api-key "(your-gemini-api-key)"
```

Explain about the parameters as follows: 

```bash
./nichenet-llm.sh \
--cell-type "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
--disease-context "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
--llm-provider "gemini" \
--model "gemini-2.5-pro" \
--lr-file "(The path of ligand-receptor interaction data file)" \
--lt-file "(The path of ligand-target interaction data file)" 
```
* For more detailed information about the parameters, please refer to [parameter-table](../../parameters.md)
* Result will be saved in the default work-directory: /results


## Expected Output
For more details, see the [example report](https://mocha.houstonmethodist.org/iS2C2/gemini-nichenet.html).

![example-output](../../screenshots/output/nichenet/openrouter/openrouter-nichenet.png)