## LIANA+ With Ollama LLM tutorial

## Installation of LLM

Install LLM Python packages

Use Python 3.9
```bash
conda create -n is2c2 python=3.9
conda activate is2c2
```
```bash
pip install -q -r requirements.txt
```

Ollama download & Install
  1. Visit the [Ollama official website](https://ollama.com/download)
  2. Download the installer for your operating system
  3. Follow the installation instructions provided

Check ollama server status

```bash
curl http://localhost:11434
```
You should see `Ollama is running`

Alternatively, you can visit http://localhost:11434 in your browser. If the Ollama server is running properly, the browser will display the following:

## Usage

### 1. Start Ollama Service
```bash
ollama serve
```

### 2. Download Example Model
> If you want to use additional models, please refer to the detailed model information on https://ollama.com/search, download your preferred model using ollama pull <model-name>, and then specify it using the --model parameter in your command.
```bash
ollama pull llama3.2
```

### 3. Run Example Analysis

```python 
python ./local-ollama-api.py \
--cell "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
--disease "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
--model "(The openmodel pulled from ollama platform)" \
--lr-file "(The path of ligand-receptor interaction data file)" \
--lt-file "(The path of ligand-target interaction data file)" \
--algorithm "liana" 

```