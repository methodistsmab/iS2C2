## LIANA+ With OpenAI LLM tutorial
> To learn more about LIANA+, please refer to the [LIANA+ documentation](https://liana-py.readthedocs.io/en/latest/notebooks/basic_usage.html).

This demonstration uses the OpenAI API via Openrouter platform, which supports the [models](https://openrouter.ai/models).

## Prerequisites
- Python 3.9
- Conda package manager
- Internet connection for downloading packages and models

---

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

---

## Prepare the API Key
Please navigate to the [Openrouter Key website](https://openrouter.ai/settings/keys) and create your own Openrouter API key.


Refer to this [PDF tutorial](../how-to-get-Openrouter-key.pdf) for step-by-step instructions on obtaining your Openrouter API key.

---

## Data
The LIANA+ example data are available in [Google Drive](https://drive.google.com/file/d/1ZifaMtldX4lvSkB1YrmA_P1V-YPVIAZM/view?usp=sharing).

**Download the example data** and place it in your working directory before proceeding with the analysis.


---


### Running LLM Hypothesis Generation with S2C2

Quick run with the example as follows:
```bash
python ./openrouter-api-call.py \
--cell "Memory CD4 T-CD14+ Mono" \
--disease "Peripheral Blood Mononuclear Cells" \
--model "openai/gpt-4.1-mini" \
--significant-branches-file "../LIANA_Output/liana_cellchat_results.csv" \
--algorithm "lianaplus" \
--api-key "(your-openrouter-api-key)"
```

Parameter explainaiton
```bash
python ./openrouter-api-call.py  \
  --cell "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
  --disease "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
  --algorithm "lianaplus" \
  --model "openai/gpt-4.1-mini"  \
  --api-key "(your-openrouter-api-key)"
```
* For more detailed information about the parameters, please refer to [parameter-table](../../parameters.md)
* Result will be saved in the default work-directory: /results


## Expected Output
For more details, see the [example report](../../output/openai_lianaplus/llm_report_openrouter_Memory_CD4_T_CD14+_Mono_Peripheral_Blood_Mononuclear_Cells_openai_gpt_41_mini_lianaplus_20250731_175658.html).

![example-output](../../screenshots/output/lianaplus/openrouter/openrouter-lianaplus.png)