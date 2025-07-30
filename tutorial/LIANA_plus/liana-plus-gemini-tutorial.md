## LIANA+ With Gemini LLM tutorial

This demonstration uses the Gemini API, which supports the following models: gemini-2.0-flash, gemini-2.5-flash, and gemini-2.5-pro. For more information, please refer to: [Gemini API docs](https://ai.google.dev/gemini-api/docs?authuser=1)

Please put your API key in the `.env` file for security purposes.


### Prepare the API Key
Please navigate to the [website](https://aistudio.google.com/apikey)and create your own Gemini API key.

Put your API key in a .env file as GEMINI_API_KEY="your-gemini-api-key", then run:
```bash
source .env
```
```bash
export TEMP_API_KEY="$GEMINI_API_KEY"
```

### Running LLM Hypothesis Generation with S2C2


```bash
python ./gemini-api-call.py\
--cell "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
--disease "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
--model "gemini-2.5-pro" \
--significant-branches-file "(The path to the CSV file containing significant ligand-receptor interaction data with downstream pathway branches)" \
--algorithm "lianaplus" \
--api-key "$TEMP_API_KEY"
```
* For more detailed information about the parameters, please refer to [parameter-table](../../parameters.md)
* Result will be saved in the default work-directory: /results